//
//  CategoryDefinitions.swift
//  ANITA
//
//  Standard category definitions matching webapp
//  Categories use proper case formatting (not all caps)
//

import Foundation

struct CategoryDefinition {
    let id: String
    let name: String // Display name (proper case, no underscores)
    let definition: String
    let keywords: [String] // Keywords for pattern matching
    let exampleDescriptions: [String]
}

class CategoryDefinitions {
    static let shared = CategoryDefinitions()
    
    // Standard categories matching webapp definitions
    let categories: [CategoryDefinition] = [
        // HOUSING & SHELTER
        CategoryDefinition(
            id: "Housing_Rent",
            name: "Rent",
            definition: "Monthly rental payments to landlords or property management companies",
            keywords: ["rent", "rental", "lease", "landlord", "apartment", "housing payment", "flat"],
            exampleDescriptions: ["rent", "monthly rent", "apartment rent", "housing payment", "lease payment", "flat rent"]
        ),
        CategoryDefinition(
            id: "Housing_Mortgage",
            name: "Mortgage",
            definition: "Monthly mortgage payments including principal and interest for home ownership",
            keywords: ["mortgage", "home loan", "principal", "interest", "house payment"],
            exampleDescriptions: ["mortgage", "home loan payment", "principal and interest", "house payment"]
        ),
        
        // UTILITIES
        CategoryDefinition(
            id: "Utilities_Electricity",
            name: "Electricity",
            definition: "Monthly electricity and power bills from utility companies",
            keywords: ["electricity", "electric", "power", "energy", "utility"],
            exampleDescriptions: ["electricity", "electric bill", "power bill", "utilities", "energy bill"]
        ),
        CategoryDefinition(
            id: "Utilities_Water",
            name: "Water & Sewage",
            definition: "Water supply and sewage treatment bills from municipal or private providers",
            keywords: ["water", "sewage", "sewer", "water bill"],
            exampleDescriptions: ["water bill", "sewage", "water and sewer", "water service"]
        ),
        CategoryDefinition(
            id: "Utilities_Gas",
            name: "Gas & Heating",
            definition: "Natural gas bills for heating, cooking, and hot water",
            keywords: ["gas", "heating", "natural gas", "gas bill", "heat"],
            exampleDescriptions: ["gas bill", "heating", "natural gas", "gas service"]
        ),
        CategoryDefinition(
            id: "Utilities_Internet_Phone",
            name: "Internet & Phone",
            definition: "Internet, mobile phone, and home phone service subscriptions",
            keywords: ["internet", "phone", "mobile", "broadband", "wifi", "cellular", "data"],
            exampleDescriptions: ["internet", "phone bill", "mobile", "broadband", "wifi", "cellular", "data plan"]
        ),
        
        // FOOD & DINING
        CategoryDefinition(
            id: "Food_Groceries",
            name: "Groceries",
            definition: "Food and household items purchased from supermarkets and grocery stores for home consumption",
            keywords: ["grocery", "groceries", "supermarket", "food store", "shopping", "food"],
            exampleDescriptions: ["groceries", "supermarket", "food shopping", "grocery", "food store", "spent on food", "on food", "for food"]
        ),
        CategoryDefinition(
            id: "Food_Dining",
            name: "Dining Out",
            definition: "Restaurants, cafes, takeout, food delivery services, and dining outside the home",
            keywords: ["restaurant", "cafe", "dining", "takeout", "delivery", "food delivery", "pizza", "burger", "lunch", "dinner", "breakfast", "coffee", "starbucks", "mcdonalds", "mcdonald", "kfc", "subway", "dominos", "papa johns", "taco bell", "wendys", "chipotle", "panera", "olive garden", "outback", "applebees", "chilis", "red lobster", "ihop", "dennys", "waffle house", "dunkin", "dunkin donuts", "five guys", "shake shack", "in-n-out", "whataburger", "jack in the box", "arbys", "panda express", "pizza hut", "little caesars", "domino", "fast food", "drive thru", "drive-through"],
            exampleDescriptions: ["restaurant", "cafe", "takeout", "food delivery", "pizza", "lunch", "dinner", "breakfast", "coffee", "burger king", "mcdonalds", "fast food"]
        ),
        
        // TRANSPORTATION
        CategoryDefinition(
            id: "Transportation_Gas",
            name: "Gas & Fuel",
            definition: "Gasoline, diesel, and other vehicle fuel purchases",
            keywords: ["gas", "fuel", "gasoline", "diesel", "petrol", "filling station", "gas station"],
            exampleDescriptions: ["gas", "fuel", "gasoline", "filling station", "gas station"]
        ),
        CategoryDefinition(
            id: "Transportation_Public",
            name: "Public Transportation",
            definition: "Buses, trains, subways, and other public transit fares",
            keywords: ["bus", "train", "subway", "metro", "transit", "public transport", "ticket"],
            exampleDescriptions: ["bus", "train", "subway", "metro", "transit ticket"]
        ),
        CategoryDefinition(
            id: "Transportation_Rideshare",
            name: "Rideshare & Taxi",
            definition: "Uber, Lyft, taxi, and other ride-hailing services",
            keywords: ["uber", "lyft", "taxi", "cab", "rideshare", "ride share"],
            exampleDescriptions: ["uber", "lyft", "taxi", "cab", "rideshare"]
        ),
        CategoryDefinition(
            id: "Transportation_Parking",
            name: "Parking & Tolls",
            definition: "Parking fees, tolls, and vehicle-related fees",
            keywords: ["parking", "toll", "parking fee", "garage"],
            exampleDescriptions: ["parking", "toll", "parking fee", "garage"]
        ),
        
        // SUBSCRIPTIONS & SERVICES
        CategoryDefinition(
            id: "Subscriptions_Streaming",
            name: "Streaming Services",
            definition: "Netflix, Spotify, Disney+, and other entertainment streaming subscriptions",
            keywords: ["netflix", "spotify", "disney", "streaming", "hulu", "amazon prime", "apple tv"],
            exampleDescriptions: ["netflix", "spotify", "disney+", "streaming service"]
        ),
        CategoryDefinition(
            id: "Subscriptions_Software",
            name: "Software & Apps",
            definition: "Software subscriptions, app subscriptions, and digital services",
            keywords: ["software", "app", "subscription", "saas", "cloud service"],
            exampleDescriptions: ["software subscription", "app subscription", "cloud service"]
        ),
        
        // SHOPPING & RETAIL
        CategoryDefinition(
            id: "Shopping_General",
            name: "Shopping",
            definition: "General shopping and retail purchases",
            keywords: ["shopping", "store", "retail", "purchase"],
            exampleDescriptions: ["shopping", "store purchase", "retail"]
        ),
        CategoryDefinition(
            id: "Clothing_Fashion",
            name: "Clothing & Fashion",
            definition: "Clothing, shoes, accessories, and fashion-related purchases",
            keywords: ["clothing", "clothes", "shoes", "fashion", "apparel", "wardrobe"],
            exampleDescriptions: ["clothing", "clothes", "shoes", "fashion", "apparel"]
        ),
        
        // ENTERTAINMENT
        CategoryDefinition(
            id: "Entertainment",
            name: "Entertainment",
            definition: "Movies, concerts, events, games, and entertainment activities",
            keywords: ["movie", "cinema", "concert", "event", "game", "entertainment", "ticket"],
            exampleDescriptions: ["movie", "cinema", "concert", "event ticket", "game"]
        ),
        
        // HEALTH & FITNESS
        CategoryDefinition(
            id: "Health_Medical",
            name: "Medical & Healthcare",
            definition: "Doctor visits, medications, health insurance, and medical expenses",
            keywords: ["doctor", "medical", "health", "pharmacy", "medicine", "hospital", "clinic"],
            exampleDescriptions: ["doctor", "medical", "pharmacy", "medicine", "hospital"]
        ),
        CategoryDefinition(
            id: "Health_Fitness",
            name: "Fitness & Gym",
            definition: "Gym memberships, fitness classes, sports equipment, and fitness-related expenses",
            keywords: ["gym", "fitness", "workout", "exercise", "sports", "yoga", "pilates"],
            exampleDescriptions: ["gym", "fitness", "workout", "sports", "yoga"]
        ),
        
        // PERSONAL CARE
        CategoryDefinition(
            id: "Personal_Care",
            name: "Personal Care",
            definition: "Haircuts, salon services, grooming products, hygiene items, and personal care services",
            keywords: ["haircut", "salon", "barber", "grooming", "hygiene", "personal care", "spa"],
            exampleDescriptions: ["haircut", "salon", "barber", "grooming", "personal care", "spa"]
        ),
        
        // EDUCATION
        CategoryDefinition(
            id: "Education",
            name: "Education",
            definition: "Tuition fees, online courses, certifications, books, and educational materials",
            keywords: ["tuition", "course", "education", "certification", "learning", "school"],
            exampleDescriptions: ["tuition", "course", "education", "certification", "learning", "school fee"]
        ),
        
        // INCOME
        CategoryDefinition(
            id: "Income_Salary",
            name: "Salary",
            definition: "Regular salary and wage income from employment",
            keywords: ["salary", "wage", "paycheck", "pay", "income", "earned"],
            exampleDescriptions: ["salary", "paycheck", "wage", "income"]
        ),
        CategoryDefinition(
            id: "Income_Freelance",
            name: "Freelance & Side Income",
            definition: "Freelance work, side gigs, and additional income sources",
            keywords: ["freelance", "side", "gig", "bonus", "commission"],
            exampleDescriptions: ["freelance", "side income", "gig", "bonus"]
        ),
        
        // OTHER
        CategoryDefinition(
            id: "Other",
            name: "Other",
            definition: "Miscellaneous expenses that don't fit into other categories",
            keywords: [],
            exampleDescriptions: []
        )
    ]
    
    // Default category
    static let defaultCategory = "Other"
    
    // Find category by matching keywords in text
    func detectCategory(from text: String) -> String {
        let lowercased = text.lowercased()
        let trimmed = lowercased.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Special handling for known restaurant/fast food chains (exact or partial matches)
        let restaurantChains = [
            "burger king", "mcdonalds", "mcdonald", "kfc", "subway", "dominos", "domino",
            "papa johns", "taco bell", "wendys", "chipotle", "panera", "olive garden",
            "outback", "applebees", "chilis", "red lobster", "ihop", "dennys", "waffle house",
            "dunkin", "dunkin donuts", "five guys", "shake shack", "in-n-out", "whataburger",
            "jack in the box", "arbys", "panda express", "pizza hut", "little caesars"
        ]
        
        // Check if text contains or is a restaurant chain name
        for chain in restaurantChains {
            if trimmed.contains(chain) || chain.contains(trimmed) {
                return "Dining Out"
            }
        }
        
        // Score each category based on keyword matches
        var categoryScores: [String: Int] = [:]
        
        for category in categories {
            var score = 0
            
            // Check keywords (weight: 1 point each)
            for keyword in category.keywords {
                let keywordLower = keyword.lowercased()
                // Exact word match gets higher score
                if lowercased == keywordLower {
                    score += 3
                } else if lowercased.contains(keywordLower) {
                    // Check if it's a whole word match (better than substring)
                    let wordPattern = "\\b\(keywordLower)\\b"
                    if let regex = try? NSRegularExpression(pattern: wordPattern, options: .caseInsensitive),
                       regex.firstMatch(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.utf16.count)) != nil {
                        score += 2
                    } else {
                        score += 1
                    }
                }
            }
            
            // Also check example descriptions (weight: 1 point each)
            for example in category.exampleDescriptions {
                if lowercased.contains(example.lowercased()) {
                    score += 1
                }
            }
            
            if score > 0 {
                categoryScores[category.name] = score
            }
        }
        
        // Return category with highest score, or default
        if let bestMatch = categoryScores.max(by: { $0.value < $1.value }), bestMatch.value > 0 {
            return bestMatch.key
        }
        
        return CategoryDefinitions.defaultCategory
    }
    
    // Get category by name (case-insensitive)
    func getCategory(name: String) -> CategoryDefinition? {
        return categories.first { $0.name.lowercased() == name.lowercased() }
    }
    
    // Get translated category name
    func getTranslatedCategoryName(_ categoryName: String) -> String {
        // Map category names to translation keys
        let categoryKeyMap: [String: String] = [
            "Rent": "category.rent",
            "Mortgage": "category.mortgage",
            "Electricity": "category.electricity",
            "Water & Sewage": "category.water_sewage",
            "Gas & Heating": "category.gas_heating",
            "Internet & Phone": "category.internet_phone",
            "Groceries": "category.groceries",
            "Dining Out": "category.dining_out",
            "Gas & Fuel": "category.gas_fuel",
            "Public Transportation": "category.public_transportation",
            "Rideshare & Taxi": "category.rideshare_taxi",
            "Parking & Tolls": "category.parking_tolls",
            "Streaming Services": "category.streaming_services",
            "Software & Apps": "category.software_apps",
            "Shopping": "category.shopping",
            "Clothing & Fashion": "category.clothing_fashion",
            "Entertainment": "category.entertainment",
            "Medical & Healthcare": "category.medical_healthcare",
            "Fitness & Gym": "category.fitness_gym",
            "Personal Care": "category.personal_care",
            "Education": "category.education",
            "Salary": "category.salary",
            "Freelance & Side Income": "category.freelance_side_income",
            "Other": "category.other"
        ]
        
        if let key = categoryKeyMap[categoryName] {
            return AppL10n.t(key)
        }
        
        // Fallback to original name if no translation found
        return categoryName
    }
    
    // Normalize category name (ensure proper case, not all caps)
    func normalizeCategory(_ category: String?) -> String {
        guard let category = category, !category.isEmpty else {
            return CategoryDefinitions.defaultCategory
        }
        
        // If already in proper format, return as is
        if let found = getCategory(name: category) {
            return found.name
        }
        
        // If it's all caps or weird format, try to match
        let lowercased = category.lowercased()
        for cat in categories {
            if cat.name.lowercased() == lowercased || cat.id.lowercased() == lowercased {
                return cat.name
            }
        }
        
        // Default to "Other" with proper case
        return CategoryDefinitions.defaultCategory
    }
}
