import Foundation

enum PriceFormatter {

    static func string(
        usd amount: Double?,
        currency: PriceCurrency = CurrencySettings.shared.preferredCurrency
    ) -> String {

        guard let amount else {
            return "--"
        }

        let convertedAmount = ExchangeRateService.shared.convertedAmount(
            usd: amount,
            to: currency
        )

        guard let convertedAmount else {
            return fallbackString(usd: amount)
        }

        return currencyString(
            amount: convertedAmount,
            currency: currency
        )
    }

    static func string(
        usd price: String?,
        currency: PriceCurrency = CurrencySettings.shared.preferredCurrency
    ) -> String {

        string(
            usd: price.flatMap(Double.init),
            currency: currency
        )
    }

    static func currencyString(
        amount: Double,
        currency: PriceCurrency
    ) -> String {

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.maximumFractionDigits = currency == .jpy ? 0 : 2
        formatter.minimumFractionDigits = currency == .jpy ? 0 : 2

        return formatter.string(from: NSNumber(value: amount)) ?? "--"
    }

    private static func fallbackString(usd amount: Double) -> String {
        currencyString(
            amount: amount,
            currency: .usd
        )
    }
}
