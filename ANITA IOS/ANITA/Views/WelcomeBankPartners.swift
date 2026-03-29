//
//  WelcomeBankPartners.swift
//  ANITA
//
//  Trust strip: tries Google favicons (high success for banks), then Clearbit.
//

import SwiftUI
import UIKit

struct WelcomeBankPartner: Identifiable, Hashable {
    let id: String
    /// Short label under / beside logo
    let name: String
    /// Domain for https://logo.clearbit.com/<domain>
    let domain: String
}

// MARK: - Popularity-led: US megabanks & card networks, global systemics, top digital (no small regionals)

enum WelcomeBankPartnerCatalog {
    static let all: [WelcomeBankPartner] = [
        .init(id: "chase", name: "Chase", domain: "chase.com"),
        .init(id: "bofa", name: "Bank of America", domain: "bankofamerica.com"),
        .init(id: "wells", name: "Wells Fargo", domain: "wellsfargo.com"),
        .init(id: "citi", name: "Citi", domain: "citi.com"),
        .init(id: "jpm", name: "J.P. Morgan", domain: "jpmorgan.com"),
        .init(id: "cap1", name: "Capital One", domain: "capitalone.com"),
        .init(id: "usbank", name: "U.S. Bank", domain: "usbank.com"),
        .init(id: "pnc", name: "PNC", domain: "pnc.com"),
        .init(id: "truist", name: "Truist", domain: "truist.com"),
        .init(id: "td", name: "TD Bank", domain: "td.com"),
        .init(id: "goldman", name: "Goldman Sachs", domain: "goldmansachs.com"),
        .init(id: "morgan", name: "Morgan Stanley", domain: "morganstanley.com"),
        .init(id: "schwab", name: "Charles Schwab", domain: "schwab.com"),
        .init(id: "disc", name: "Discover", domain: "discover.com"),
        .init(id: "amex", name: "American Express", domain: "americanexpress.com"),
        .init(id: "visa", name: "Visa", domain: "visa.com"),
        .init(id: "mastercard", name: "Mastercard", domain: "mastercard.com"),
        .init(id: "paypal", name: "PayPal", domain: "paypal.com"),
        .init(id: "fidelity", name: "Fidelity", domain: "fidelity.com"),
        .init(id: "vanguard", name: "Vanguard", domain: "vanguard.com"),
        .init(id: "nfcu", name: "Navy Federal", domain: "navyfederal.org"),
        .init(id: "usaa", name: "USAA", domain: "usaa.com"),
        .init(id: "chime", name: "Chime", domain: "chime.com"),
        .init(id: "sofi", name: "SoFi", domain: "sofi.com"),
        .init(id: "ally", name: "Ally", domain: "ally.com"),
        .init(id: "venmo", name: "Venmo", domain: "venmo.com"),
        .init(id: "rh", name: "Robinhood", domain: "robinhood.com"),
        .init(id: "etrade", name: "E*TRADE", domain: "etrade.com"),
        .init(id: "ibkr", name: "Interactive Brokers", domain: "interactivebrokers.com"),
        .init(id: "marcus", name: "Marcus", domain: "marcus.com"),
        .init(id: "wise", name: "Wise", domain: "wise.com"),
        .init(id: "revolut", name: "Revolut", domain: "revolut.com"),
        .init(id: "bny", name: "BNY", domain: "bnymellon.com"),
        .init(id: "statest", name: "State Street", domain: "statestreet.com"),
        .init(id: "icbc", name: "ICBC", domain: "icbc.com.cn"),
        .init(id: "ccb", name: "China Construction Bank", domain: "ccb.com"),
        .init(id: "boc", name: "Bank of China", domain: "boc.cn"),
        .init(id: "abc", name: "Agricultural Bank of China", domain: "abchina.com"),
        .init(id: "mizuho", name: "Mizuho", domain: "mizuhogroup.com"),
        .init(id: "smfg", name: "SMBC Group", domain: "smbcgroup.com"),
        .init(id: "hsbc", name: "HSBC", domain: "hsbc.com"),
        .init(id: "barc", name: "Barclays", domain: "barclays.com"),
        .init(id: "bnp", name: "BNP Paribas", domain: "bnpparibas.com"),
        .init(id: "db", name: "Deutsche Bank", domain: "db.com"),
        .init(id: "ubs", name: "UBS", domain: "ubs.com"),
        .init(id: "santander", name: "Santander", domain: "santander.com"),
        .init(id: "credit_agricole", name: "Crédit Agricole", domain: "credit-agricole.com"),
        .init(id: "societe", name: "SocGen", domain: "societegenerale.com"),
        .init(id: "ing", name: "ING", domain: "ing.com"),
        .init(id: "rbc", name: "RBC", domain: "rbc.com"),
        .init(id: "scotia", name: "Scotiabank", domain: "scotiabank.com"),
        .init(id: "bmo", name: "BMO", domain: "bmo.com"),
        .init(id: "cibc", name: "CIBC", domain: "cibc.com"),
        .init(id: "stan", name: "Standard Chartered", domain: "sc.com"),
        .init(id: "lloyds", name: "Lloyds", domain: "lloydsbank.com"),
        .init(id: "natwest", name: "NatWest", domain: "natwest.com"),
        .init(id: "anz", name: "ANZ", domain: "anz.com"),
        .init(id: "cba", name: "CommBank", domain: "commbank.com.au"),
        .init(id: "westpac", name: "Westpac", domain: "westpac.com.au"),
        .init(id: "nab", name: "NAB", domain: "nab.com.au"),
        .init(id: "itau", name: "Itaú", domain: "itau.com.br"),
        .init(id: "brad", name: "Bradesco", domain: "bradesco.com.br"),
        .init(id: "bbva", name: "BBVA", domain: "bbva.com"),
        .init(id: "nordea", name: "Nordea", domain: "nordea.com"),
        .init(id: "danske", name: "Danske Bank", domain: "danskebank.com"),
        .init(id: "rabo", name: "Rabobank", domain: "rabobank.com"),
        .init(id: "ntrs", name: "Northern Trust", domain: "northerntrust.com"),
        .init(id: "synchrony", name: "Synchrony", domain: "synchrony.com"),
        .init(id: "blackrock", name: "BlackRock", domain: "blackrock.com"),
    ]
    
    /// Domains for the welcome marquee (Stripe + banks); used for cache warming.
    static var marqueePrefetchDomains: [String] {
        ["stripe.com"] + all.map(\.domain)
    }
}

// MARK: - Logo prefetch (warm URLCache so tiles show bitmaps without spinners)

enum WelcomePartnerLogoPrefetch {
    /// Fire-and-forget: run when Welcome opens so icons resolve from cache by the time the strip is visible.
    static func warmMarqueeDomains() {
        let domains = WelcomeBankPartnerCatalog.marqueePrefetchDomains
        Task.detached(priority: .utility) {
            await prefetchBatched(domains: domains)
        }
    }
    
    private static func prefetchBatched(domains: [String]) async {
        let batchSize = 10
        for start in stride(from: 0, to: domains.count, by: batchSize) {
            let end = min(start + batchSize, domains.count)
            let slice = Array(domains[start..<end])
            await withTaskGroup(of: Void.self) { group in
                for domain in slice {
                    group.addTask {
                        await prefetchOne(domain: domain)
                    }
                }
            }
        }
    }
    
    private static func prefetchOne(domain: String) async {
        for url in WelcomePartnerLogoSources.candidateURLs(domain: domain).prefix(3) {
            var req = URLRequest(url: url)
            req.cachePolicy = .returnCacheDataElseLoad
            req.timeoutInterval = 20
            _ = try? await URLSession.shared.data(for: req)
        }
    }
}

// MARK: - Logo URLs (shared by prefetch + loader)

private enum WelcomePartnerLogoSources {
    static func candidateURLs(domain: String) -> [URL] {
        var urls: [URL] = []
        if let u = googleFavicon(domain: domain, size: "128") { urls.append(u) }
        if let u = googleFavicon(domain: domain, size: "64") { urls.append(u) }
        if let u = URL(string: "https://logo.clearbit.com/\(domain)") { urls.append(u) }
        if let u = URL(string: "https://icons.duckduckgo.com/ip3/\(domain).ico") { urls.append(u) }
        return urls
    }
    
    private static func googleFavicon(domain: String, size: String) -> URL? {
        var c = URLComponents(string: "https://www.google.com/s2/favicons")
        c?.queryItems = [
            URLQueryItem(name: "sz", value: size),
            URLQueryItem(name: "domain", value: domain)
        ]
        return c?.url
    }
}

// MARK: - Remote logo (URLSession + fallbacks; monogram if nothing decodes — chip always visible)

private enum WelcomeBankLogoMetrics {
    static let tile: CGFloat = 48
    static let img: CGFloat = 30
    static let corner: CGFloat = 13
    /// Fixed caption band so every chip has the same footprint and icon tiles line up.
    static let captionHeight: CGFloat = 32
    static let captionWidth: CGFloat = 84
    static let iconLabelGap: CGFloat = 6
    static let marqueeChipSpacing: CGFloat = 12
}

private struct WelcomePartnerRemoteLogo: View {
    let domain: String
    let name: String
    let imageSide: CGFloat
    /// `true` when a remote bitmap is shown; `false` when only the monogram fallback is shown.
    var onBitmapLoaded: ((Bool) -> Void)? = nil
    
    @State private var uiImage: UIImage?
    @State private var showMonogram = false
    
    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSide, height: imageSide)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else if showMonogram {
                WelcomeBankMonogram(name: name, side: imageSide)
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: imageSide * 0.18, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: imageSide, height: imageSide)
            }
        }
        .animation(.easeOut(duration: 0.22), value: uiImage != nil)
        .animation(.easeOut(duration: 0.18), value: showMonogram)
        .task(id: domain) {
            await loadFromNetwork()
        }
    }
    
    private func loadFromNetwork() async {
        await MainActor.run {
            uiImage = nil
            showMonogram = false
        }
        for url in WelcomePartnerLogoSources.candidateURLs(domain: domain) {
            var req = URLRequest(url: url)
            req.cachePolicy = .returnCacheDataElseLoad
            req.timeoutInterval = 18
            req.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { continue }
                guard !data.isEmpty else { continue }
                let decoded = await MainActor.run { () -> Bool in
                    guard let img = UIImage(data: data), img.size.width >= 2, img.size.height >= 2 else { return false }
                    uiImage = img
                    onBitmapLoaded?(true)
                    return true
                }
                if decoded { return }
            } catch {
                continue
            }
        }
        await MainActor.run {
            showMonogram = true
            onBitmapLoaded?(false)
        }
    }
}

private struct WelcomeBankMonogram: View {
    let name: String
    var side: CGFloat = 38
    
    private var initials: String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            let a = parts[0].prefix(1)
            let b = parts[1].prefix(1)
            return "\(a)\(b)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    var body: some View {
        Text(initials)
            .font(.system(size: max(12, side * 0.34), weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.42, blue: 0.52),
                        Color(red: 0.35, green: 0.35, blue: 0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - Logo chip (icon above label — classic strip; icons align via top HStack + fixed caption height)

private struct WelcomeBankLogoChip: View {
    let partner: WelcomeBankPartner
    
    private var tile: CGFloat { WelcomeBankLogoMetrics.tile }
    private var img: CGFloat { WelcomeBankLogoMetrics.img }
    private var corner: CGFloat { WelcomeBankLogoMetrics.corner }
    private var isStripe: Bool { partner.id == "stripe" }
    
    private static let stripeFill = Color(red: 0.39, green: 0.36, blue: 0.98)
    
    @State private var stripeLogoFailed = false
    
    var body: some View {
        VStack(spacing: WelcomeBankLogoMetrics.iconLabelGap) {
            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(isStripe ? Self.stripeFill : Color(white: 0.97))
                    .frame(width: tile, height: tile)
                    .shadow(color: Color.black.opacity(isStripe ? 0.35 : 0.22), radius: isStripe ? 6 : 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(isStripe ? Color.white.opacity(0.22) : Color.black.opacity(0.06), lineWidth: 1)
                    )
                if isStripe {
                    RoundedRectangle(cornerRadius: corner * 0.45, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .frame(width: tile * 0.62, height: tile * 0.62)
                }
                if isStripe && stripeLogoFailed {
                    Text("S")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Self.stripeFill)
                } else {
                    WelcomePartnerRemoteLogo(
                        domain: partner.domain,
                        name: partner.name,
                        imageSide: isStripe ? img * 0.88 : img,
                        onBitmapLoaded: { isBitmap in
                            if isStripe, !isBitmap {
                                stripeLogoFailed = true
                            }
                        }
                    )
                }
            }
            .frame(width: tile, height: tile)
            
            Text(partner.name)
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundColor(.white.opacity(isStripe ? 0.9 : 0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
                .frame(
                    width: WelcomeBankLogoMetrics.captionWidth,
                    height: WelcomeBankLogoMetrics.captionHeight,
                    alignment: .center
                )
        }
        .frame(width: WelcomeBankLogoMetrics.captionWidth)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(partner.name)
    }
}

// MARK: - Marquee (Stripe first, then banks)

struct WelcomePartnerTrustStrip: View {
    let reduceMotion: Bool
    
    @State private var segmentWidth: CGFloat = 7200
    
    private var marqueePartners: [WelcomeBankPartner] {
        [.init(id: "stripe", name: "Stripe", domain: "stripe.com")] + WelcomeBankPartnerCatalog.all
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text(AppL10n.t("welcome.working_with"))
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundColor(.white.opacity(0.42))
                .tracking(1.2)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .offset(y: -6)
            
            welcomeMarquee
                .frame(height: WelcomeBankLogoMetrics.tile
                    + WelcomeBankLogoMetrics.iconLabelGap
                    + WelcomeBankLogoMetrics.captionHeight
                    + 10)
                .clipped()
            
            Text(AppL10n.t("welcome.secured_by_stripe"))
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundColor(.white.opacity(0.56))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var welcomeMarquee: some View {
        if reduceMotion {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: WelcomeBankLogoMetrics.marqueeChipSpacing) {
                    ForEach(marqueePartners) { p in
                        WelcomeBankLogoChip(partner: p)
                    }
                }
                .padding(.vertical, 4)
            }
        } else {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: reduceMotion)) { ctx in
                    let speed: CGFloat = 32
                    let t = CGFloat(ctx.date.timeIntervalSinceReferenceDate)
                    let w = max(segmentWidth, 1)
                    let x = -(t * speed).truncatingRemainder(dividingBy: w)
                    HStack(spacing: 0) {
                        partnerRow
                            .background(
                                GeometryReader { g in
                                    Color.clear.preference(key: WelcomeMarqueeWidthKey.self, value: g.size.width)
                                }
                            )
                        partnerRow
                    }
                    .offset(x: x)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .onPreferenceChange(WelcomeMarqueeWidthKey.self) { segmentWidth = $0 }
        }
    }
    
    private var partnerRow: some View {
        HStack(alignment: .top, spacing: WelcomeBankLogoMetrics.marqueeChipSpacing) {
            ForEach(marqueePartners) { p in
                WelcomeBankLogoChip(partner: p)
            }
        }
        .padding(.trailing, 24)
    }
}

private struct WelcomeMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
