import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12
import QtGraphicalEffects 1.0

import "../../Components"
import "../../Constants"

FloatingBackground {
    id: root

    property alias field: input_volume.field
    property bool my_side: false
    property bool enabled: true
    property alias column_layout: form_layout

    function getFiatText(v, ticker) {
        return General.formatFiat('', v === '' ? 0 : API.get().get_fiat_from_amount(ticker, v), API.get().current_fiat) + " " +  General.cex_icon
    }

    function canShowFees() {
        return my_side && valid_trade_info && !General.isZero(getVolume())
    }

    function getVolume() {
        return input_volume.field.text === '' ? '0' :  input_volume.field.text
    }

    function fieldsAreFilled() {
        return input_volume.field.text !== ''
    }

    function hasEthFees() {
        return General.fieldExists(curr_trade_info.erc_fees) && parseFloat(curr_trade_info.erc_fees) > 0
    }

    function hasEnoughEthForFees() {
        return General.isEthEnabled() && API.get().do_i_have_enough_funds("ETH", curr_trade_info.erc_fees)
    }

    function higherThanMinTradeAmount() {
        return input_volume.field.text !== '' && parseFloat(input_volume.field.text) >= General.getMinTradeAmount()
    }

    function isValid() {
        let valid = true

        // Both sides
        if(valid) valid = fieldsAreFilled()
        if(valid) valid = higherThanMinTradeAmount()

        if(!my_side) return valid

        // Sell side
        if(valid) valid = !notEnoughBalance()
        if(valid) valid = API.get().do_i_have_enough_funds(getTicker(my_side), input_volume.field.text)
        if(valid && hasEthFees()) valid = hasEnoughEthForFees()

        return valid
    }

    function getMaxVolume() {
        return API.get().get_balance(getTicker(my_side))
    }

    function getMaxTradableVolume(set_as_current) {
        // set_as_current should be true if input_volume is updated
        // if it's called for cap check, it should be false because that's not the current input_volume
        return getSendAmountAfterFees(getMaxVolume(), set_as_current)
    }

    function setMax() {
        input_volume.field.text = getMaxTradableVolume(true)
    }

    function reset(is_base) {
        if(my_side) {
            // is_base info comes from the ComboBox ticker change in OrderForm.
            // At other places it's not given.
            // We don't want to reset base balance at rel ticker change
            // Therefore it will reset only if this info is set from ComboBox -> setPair
            // Or if it's from somewhere else like page change, in that case is_base is undefined
            if(is_base === undefined || is_base) setMax()
        }
        else {
            input_volume.field.text = ''
        }
    }

    function capVolume() {
        if(inCurrentPage() && my_side && input_volume.field.acceptableInput) {
            const amt = parseFloat(input_volume.field.text)
            const cap_with_fees = getMaxTradableVolume(false)
            if(amt > cap_with_fees) {
                input_volume.field.text = cap_with_fees.toString()
                return true
            }
        }

        return false
    }

    function notEnoughBalance() {
        return my_side && parseFloat(getMaxVolume()) < General.getMinTradeAmount()
    }

    function shouldBlockInput() {
        return my_side && (notEnoughBalance() || notEnoughBalanceForFees())
    }

    function onBaseChanged() {
        if(capVolume()) updateTradeInfo()

        if(my_side) {
            // Rel is dependant on Base if price is set so update that
            updateRelAmount()

            // Update the new fees, input_volume might be changed
            updateTradeInfo()
        }
    }

    implicitHeight: form_layout.height

    ColumnLayout {
        id: form_layout
        width: parent.width

        ColumnLayout {
            Layout.alignment: Qt.AlignTop

            Layout.fillWidth: true
            spacing: 15

            // Top Line
            RowLayout {
                id: top_line
                Layout.topMargin: parent.spacing
                Layout.leftMargin: parent.spacing*2
                Layout.rightMargin: Layout.leftMargin

                // Title
                DefaultText {
                    font.pixelSize: Style.textSizeMid2
                    text_value: API.get().empty_string + (my_side ? qsTr("Sell") : qsTr("Receive"))
                    color: my_side ? Style.colorRed : Style.colorGreen
                    font.weight: Font.Bold
                }

                Arrow {
                    up: my_side
                    color: my_side ? Style.colorRed : Style.colorGreen
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                }

                DefaultImage {
                    source: General.coinIcon(getTicker(my_side))
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: Layout.preferredWidth
                }
            }


            HorizontalLine {
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: top_line.Layout.leftMargin
                Layout.rightMargin: top_line.Layout.rightMargin

                DefaultText {
                    text_value: API.get().empty_string + (qsTr("Amount") + ':')
                    font.pixelSize: Style.textSizeSmall1
                }

                Item {
                    Layout.fillWidth: true
                    height: input_volume.height

                    AmountField {
                        id: input_volume
                        width: parent.width
                        field.enabled: root.enabled && !shouldBlockInput()
                        field.placeholderText: API.get().empty_string + (my_side ? qsTr("Amount to sell") :
                                                         field.enabled ? qsTr("Amount to receive") : qsTr("Please fill the send amount"))
                        field.onTextChanged: {
                            const before_checks = field.text
                            onBaseChanged()
                            const after_checks = field.text

                            // Update slider only if the value is not from slider, or value got corrected here
                            if(before_checks !== after_checks || !input_volume_slider.updating_text_field) {
                                input_volume_slider.updating_from_text_field = true
                                input_volume_slider.value = parseFloat(field.text)
                                input_volume_slider.updating_from_text_field = false
                            }
                        }

                        function resetPrice() {
                            if(!my_side && orderIsSelected()) resetPreferredPrice()
                        }

                        field.onPressed: resetPrice()
                        field.onFocusChanged: {
                            if(field.activeFocus) resetPrice()
                        }

                        field.font.pixelSize: Style.textSizeSmall1
                        field.font.weight: Font.Bold
                    }

                    DefaultText {
                        anchors.left: input_volume.left
                        anchors.top: input_volume.bottom
                        anchors.topMargin: 5

                        text_value: getFiatText(input_volume.field.text, getTicker(my_side))
                        font.pixelSize: input_volume.field.font.pixelSize

                        CexInfoTrigger {}
                    }

                    DefaultText {
                        anchors.right: input_volume.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: input_volume.verticalCenter

                        text_value: getTicker(my_side)
                        font.pixelSize: input_volume.field.font.pixelSize
                    }
                }
            }


            Slider {
                id: input_volume_slider
                function getRealValue() {
                    return input_volume_slider.position * (input_volume_slider.to - input_volume_slider.from)
                }

                enabled: input_volume.field.enabled
                property bool updating_from_text_field: false
                property bool updating_text_field: false
                readonly property int precision: General.getRecommendedPrecision(to)
                visible: my_side
                Layout.fillWidth: true
                Layout.leftMargin: top_line.Layout.leftMargin
                Layout.rightMargin: top_line.Layout.rightMargin
                Layout.bottomMargin: top_line.Layout.rightMargin
                from: 0
                stepSize: 1/Math.pow(10, precision)
                to: parseFloat(getMaxVolume())
                live: false

                onValueChanged: {
                    if(updating_from_text_field) return

                    if(pressed) {
                        updating_text_field = true
                        input_volume.field.text = General.formatDouble(value)
                        updating_text_field = false
                    }
                }

                DefaultText {
                    visible: parent.pressed
                    anchors.horizontalCenter: parent.handle.horizontalCenter
                    anchors.bottom: parent.handle.top

                    text_value: General.formatDouble(input_volume_slider.getRealValue(), input_volume_slider.precision)
                    font.pixelSize: input_volume.field.font.pixelSize
                }

                DefaultText {
                    anchors.left: parent.left
                    anchors.top: parent.bottom

                    text_value: API.get().empty_string + (qsTr("Min"))
                    font.pixelSize: input_volume.field.font.pixelSize
                }
                DefaultText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom

                    text_value: API.get().empty_string + (qsTr("Half"))
                    font.pixelSize: input_volume.field.font.pixelSize
                }
                DefaultText {
                    anchors.right: parent.right
                    anchors.top: parent.bottom

                    text_value: API.get().empty_string + (qsTr("Max"))
                    font.pixelSize: input_volume.field.font.pixelSize
                }
            }


            // Fees
            InnerBackground {
                visible: my_side

                radius: 100
                id: bg
                Layout.fillWidth: true
                Layout.leftMargin: top_line.Layout.leftMargin
                Layout.rightMargin: top_line.Layout.rightMargin
                Layout.bottomMargin: layout_margin

                content: RowLayout {
                    width: bg.width
                    height: tx_fee_text.font.pixelSize * 4

                    ColumnLayout {
                        id: fees
                        visible: canShowFees()

                        spacing: -2
                        Layout.leftMargin: 10
                        Layout.rightMargin: Layout.leftMargin
                        Layout.alignment: Qt.AlignLeft

                        DefaultText {
                            id: tx_fee_text
                            text_value: API.get().empty_string + ((qsTr('Transaction Fee') + ': ' + General.formatCrypto("", curr_trade_info.tx_fee, curr_trade_info.is_ticker_of_fees_eth ? "ETH" : getTicker(true))) +
                                                                    // ETH Fees
                                                                    (hasEthFees() ? " + " + General.formatCrypto("", curr_trade_info.erc_fees, 'ETH') : '') +

                                                                  // Fiat part
                                                                  (" ("+
                                                                      getFiatText(!hasEthFees() ? curr_trade_info.tx_fee : General.formatDouble((parseFloat(curr_trade_info.tx_fee) + parseFloat(curr_trade_info.erc_fees))),
                                                                                  curr_trade_info.is_ticker_of_fees_eth ? 'ETH' : getTicker(true))
                                                                   +")")


                                                                  )
                            font.pixelSize: Style.textSizeSmall1

                            CexInfoTrigger {}
                        }

                        DefaultText {
                            text_value: API.get().empty_string + (qsTr('Trading Fee') + ': ' + General.formatCrypto("", curr_trade_info.trade_fee, getTicker(true)) +

                                                                  // Fiat part
                                                                  (" ("+
                                                                      getFiatText(curr_trade_info.trade_fee, getTicker(true))
                                                                   +")")
                                                                  )
                            font.pixelSize: tx_fee_text.font.pixelSize

                            CexInfoTrigger {}
                        }
                    }


                    DefaultText {
                        visible: !fees.visible

                        text_value: API.get().empty_string + (qsTr('Fees will be calculated'))
                        Layout.alignment: Qt.AlignCenter
                        font.pixelSize: tx_fee_text.font.pixelSize
                    }
                }
            }
        }

        // Trade button
        DefaultButton {
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            Layout.topMargin: 5
            Layout.rightMargin: top_line.Layout.rightMargin
            Layout.bottomMargin: layout_margin

            visible: !my_side
            width: 170

            text: API.get().empty_string + (!preffered_order.is_asks && orderIsSelected() ? qsTr("Match Order") : qsTr("Create Order"))
            enabled: valid_trade_info && !notEnoughBalanceForFees() && form_base.isValid() && form_rel.isValid()
            onClicked: confirm_trade_modal.open()
        }
    }
}
