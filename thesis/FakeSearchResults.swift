import Foundation
import Core451
#if canImport(SwiftUI)
import SwiftUI
#endif

public struct SearchSnippet: Identifiable, Hashable, Codable {
    public let id: UUID
    public let resultID: UUID
    public let index: Int
    public let title: String
    public let tags: [String]
    public let url: String
    public let snippet: String

    public init(id: UUID = UUID(), resultID: UUID, index: Int, title: String, tags: [String] = [], url: String, snippet: String) {
        self.id = id
        self.resultID = resultID
        self.index = index
        self.title = title
        self.tags = tags
        self.url = url
        self.snippet = snippet
    }
}

public struct SearchResult: Identifiable, Hashable, Codable {
    public let id: UUID
    public let query: String
    public let snippets: [SearchSnippet]

    public init(id: UUID = UUID(), query: String, snippets: [SearchSnippet]) {
        self.id = id
        self.query = query
        self.snippets = snippets
    }
}

public struct SearchResponse: Hashable, Codable {
    public let timestamp: Date
    public let results: [SearchResult]

    public init(timestamp: Date = .init(), results: [SearchResult]) {
        self.timestamp = timestamp
        self.results = results
    }
}

public enum FakeScenario: CaseIterable {
    case climateChangePolicy
    case aiInEducation
    case nutritionAndLongevity
    case urbanTransit

    public var title: String {
        switch self {
        case .climateChangePolicy: return "Climate Change Policy in Coastal Cities"
        case .aiInEducation: return "AI in Education: Benefits and Risks"
        case .nutritionAndLongevity: return "Nutrition and Longevity: Evidence Overview"
        case .urbanTransit: return "Urban Transit Innovations in Mid-Sized Cities"
        }
    }

    public var baseURL: String {
        switch self {
        case .climateChangePolicy: return "https://example.org/climate"
        case .aiInEducation: return "https://example.org/education-ai"
        case .nutritionAndLongevity: return "https://example.org/nutrition"
        case .urbanTransit: return "https://example.org/transit"
        }
    }
}

public enum FakeSearchResults {
    public static func makeResponse() -> SearchResponse {
        let results = FakeScenario.allCases.map { makeResult(for: $0) }
        return SearchResponse(results: results)
    }

    public static var allResults: [SearchResult] {
        FakeScenario.allCases.map { makeResult(for: $0) }
    }

    /// Returns four SearchResult entries (one per scenario), each containing 10 snippets.
    public static var fourSetsOfTen: [SearchResult] {
        FakeScenario.allCases.map { makeResult(for: $0) }
    }

    /// Returns a flattened list of all 40 snippets across all scenarios.
    public static var allSnippets: [SearchSnippet] {
        fourSetsOfTen.flatMap { $0.snippets }
    }
    
    /// Matches a user query to the most relevant scenario based on keywords
    public static func matchScenario(for query: String) -> FakeScenario? {
        let lowercased = query.lowercased()
        
        // Climate change keywords
        if lowercased.contains("climate") || lowercased.contains("flood") ||
           lowercased.contains("sea level") || lowercased.contains("coastal") ||
           lowercased.contains("hurricane") || lowercased.contains("storm") ||
           lowercased.contains("wetland") || lowercased.contains("insurance") ||
           lowercased.contains("adaptation") || lowercased.contains("erosion") {
            return .climateChangePolicy
        }
        
        // AI in education keywords
        if lowercased.contains("ai") || lowercased.contains("education") ||
           lowercased.contains("student") || lowercased.contains("teacher") ||
           lowercased.contains("learning") || lowercased.contains("school") ||
           lowercased.contains("tutor") || lowercased.contains("classroom") ||
           lowercased.contains("homework") || lowercased.contains("grade") {
            return .aiInEducation
        }
        
        // Nutrition keywords
        if lowercased.contains("nutrition") || lowercased.contains("diet") ||
           lowercased.contains("food") || lowercased.contains("health") ||
           lowercased.contains("vitamin") || lowercased.contains("protein") ||
           lowercased.contains("longevity") || lowercased.contains("aging") ||
           lowercased.contains("microbiome") || lowercased.contains("supplement") {
            return .nutritionAndLongevity
        }
        
        // Transit keywords
        if lowercased.contains("transit") || lowercased.contains("bus") ||
           lowercased.contains("bike") || lowercased.contains("transport") ||
           lowercased.contains("subway") || lowercased.contains("train") ||
           lowercased.contains("commute") || lowercased.contains("fare") ||
           lowercased.contains("cycling") || lowercased.contains("electric bus") {
            return .urbanTransit
        }
        
        return nil
    }
    
    /// Searches for results based on a user query by matching to a scenario
    public static func search(query: String) -> SearchResult? {
        guard let scenario = matchScenario(for: query) else {
            return nil
        }
        return makeResult(for: scenario)
    }

    public static func makeResult(for scenario: FakeScenario) -> SearchResult {
        let query = scenario.title
        let resultID = UUID()
        
        var snippets: [SearchSnippet] = []
        for i in 1...10 {
            let snippetData = getSnippetData(for: scenario, index: i, resultID: resultID)
            snippets.append(snippetData)
        }
        return SearchResult(id: resultID, query: query, snippets: snippets)
    }
    
    private static func getSnippetData(for scenario: FakeScenario, index: Int, resultID: UUID) -> SearchSnippet {
        switch scenario {
        case .climateChangePolicy:
            return climateChangeSnippet(index: index, resultID: resultID)
        case .aiInEducation:
            return aiEducationSnippet(index: index, resultID: resultID)
        case .nutritionAndLongevity:
            return nutritionSnippet(index: index, resultID: resultID)
        case .urbanTransit:
            return transitSnippet(index: index, resultID: resultID)
        }
    }
    
    private static func climateChangeSnippet(index: Int, resultID: UUID) -> SearchSnippet {
        switch index {
        case 1:
            return SearchSnippet(
                resultID: resultID,
                index: 1,
                title: "Adaptive Infrastructure Investments Show 40% Flood Damage Reduction",
                tags: ["Climate", "Infrastructure", "Equity", "Research"],
                url: "https://example.org/climate/adaptive-infrastructure-study",
                snippet: """
                A comprehensive 2024 study published in Nature Climate Change analyzed infrastructure investments across 47 coastal metropolitan areas. The data is stark: cities that invested in adaptive infrastructure between 2010-2020 saw 37-43% reductions in flood-related property damage compared to control cities. The study tracked $12.8 billion in spending on elevated roadways, improved drainage systems, and reinforced seawalls. Critics, however, point out that these investments disproportionately protected wealthier neighborhoods. Dr. Maria Chen, lead author, notes: "We found significant correlation between median household income and proximity to adaptation infrastructure." The equity dimension cannot be ignored.
                """
            )
        case 2:
            return SearchSnippet(
                resultID: resultID,
                index: 2,
                title: "New Orleans Wetlands Restoration: A Model for Nature-Based Solutions",
                tags: ["Climate", "Wetlands", "Nature", "New Orleans"],
                url: "https://example.org/climate/nola-wetlands-restoration",
                snippet: """
                "When Hurricane Ida hit, our neighborhood stayed dry for the first time in twenty years." That's how Rosa Martinez describes the impact of restored wetlands in her New Orleans community. The city's $340 million investment in 1,200 acres of coastal wetlands has become a model for nature-based solutions. But is it scalable? Urban ecologist James Park argues that while wetlands work well for storm surge, they require enormous space and decades to mature. "Miami doesn't have 1,200 acres of available waterfront," he points out. Meanwhile, initial biodiversity surveys show promising returns: 23 bird species have returned to areas where they'd been absent since the 1970s.
                """
            )
        case 3:
            return SearchSnippet(
                resultID: resultID,
                index: 3,
                title: "Climate Adaptation ROI: Rotterdam vs Venice Case Study",
                tags: ["Climate", "Economics", "ROI", "Case Study"],
                url: "https://example.org/climate/adaptation-economics",
                snippet: """
                The economic case for climate adaptation is more nuanced than advocates suggest. Yes, a 2023 World Bank analysis found 15-20 year ROI for certain interventions. But which interventions? Elevated buildings show positive returns in high-risk flood zones, while massive seawall projects often fail cost-benefit analysis. The Rotterdam model—combining flood barriers with urban amenities like parks and performance spaces—achieved $2.40 return per dollar spent. Contrast this with Venice's MOSE barriers: €6 billion invested, ongoing maintenance costs exceeding projections by 340%, and questions about long-term effectiveness. The devil is in the implementation details.
                """
            )
        case 4:
            return SearchSnippet(
                resultID: resultID,
                index: 4,
                title: "Community Engagement: Charleston Success vs Virginia Beach Failure",
                tags: ["Climate", "Community", "Planning", "Governance"],
                url: "https://example.org/climate/community-engagement-lessons",
                snippet: """
                Community engagement or community fatigue? Charleston's adaptation planning process included 47 public meetings over two years, resulting in a comprehensive strategy with 71% public support. Compare this to Virginia Beach, where rushed planning and poor communication led to protests and a rejected bond measure. The difference? Charleston hired professional facilitators, provided childcare at meetings, translated materials into five languages, and conducted door-to-door surveys in underrepresented neighborhoods. This level of engagement cost $1.2 million—money well spent, according to city manager David Torres: "We would have wasted far more on a failed implementation."
                """
            )
        case 5:
            return SearchSnippet(
                resultID: resultID,
                index: 5,
                title: "San Francisco's Tiered Trigger Approach to Sea Level Rise",
                tags: ["Climate", "Sea Level", "San Francisco", "Policy"],
                url: "https://example.org/climate/tiered-trigger-approach",
                snippet: """
                Sea level rise projections: 1-2 feet by 2050 (moderate scenario), 3-5 feet by 2100. But projections are not predictions. The latest IPCC models show wider uncertainty bands than previous versions as scientists better understand ice sheet dynamics and thermal expansion variability. What does this mean for policy? San Francisco adopted a "tiered trigger" approach: baseline protections now, with predetermined escalations when monitoring stations detect specific thresholds. Stage 1 triggers at 6 inches of rise, Stage 2 at 12 inches, Stage 3 at 24 inches. Each stage has pre-approved funding mechanisms and engineering plans. The approach acknowledges uncertainty while ensuring preparedness.
                """
            )
        case 6:
            return SearchSnippet(
                resultID: resultID,
                index: 6,
                title: "Insurance Companies Flee Coastal Markets as Premiums Spike 47%",
                tags: ["Climate", "Insurance", "Economics", "Florida"],
                url: "https://example.org/climate/insurance-exodus",
                snippet: """
                The insurance exodus from coastal markets is accelerating faster than predicted. State Farm, Allstate, and seven regional carriers have stopped writing new homeowner policies in high-risk Florida counties. Premiums in remaining markets increased 47% year-over-year in 2024. Some economists view this as a healthy market signal—why subsidize construction in doomed locations? Others worry about economic collapse in coastal communities. Louisiana's solution: state-backed insurance pools funded by property taxes, effectively socializing risk. Florida tried tax credits for resilience improvements—$50M allocated, but uptake was only 23% due to complex application processes and upfront cost barriers.
                """
            )
        case 7:
            return SearchSnippet(
                resultID: resultID,
                index: 7,
                title: "San Diego's Integrated Coastal Zone Management Success Story",
                tags: ["Climate", "Coordination", "San Diego", "Governance"],
                url: "https://example.org/climate/san-diego-coordination",
                snippet: """
                Integrated coastal zone management sounds great in theory. In practice, it means getting multiple agencies to actually coordinate. The San Diego regional program brings together 18 cities, 4 counties, state coastal commission, federal EPA, port authorities, and 12 environmental organizations. Transaction costs are enormous—the coordination office employs 34 full-time staff just to manage meetings and data sharing. Yet the outcomes justify the investment: unified monitoring networks, compatible zoning codes, joint grant applications that secured $890M in federal funding. The key? A legal framework giving the coordination body actual authority, not just advisory powers.
                """
            )
        case 8:
            return SearchSnippet(
                resultID: resultID,
                index: 8,
                title: "Managed Retreat in Louisiana: Heritage vs Survival",
                tags: ["Climate", "Migration", "Louisiana", "Community"],
                url: "https://example.org/climate/managed-retreat-louisiana",
                snippet: """
                Is "managed retreat" just a euphemism for giving up? That's how property owners in Isle de Jean Charles, Louisiana, characterized the federal buyout program. The government offered to relocate the entire community inland—fair market value for homes plus relocation assistance. Sounds reasonable until you understand these families have lived on this land for seven generations. "You can't put a price on heritage," argues community leader Albert Naquin. Yet the island loses a football field of land every month to erosion. Thirty years ago, 400 people lived here; now it's 40. The youngest residents tend to support relocation; elders want to stay. Climate migration isn't just about infrastructure—it's about identity.
                """
            )
        case 9:
            return SearchSnippet(
                resultID: resultID,
                index: 9,
                title: "AI Storm Surge Prediction: 89% Accurate but Limitations Remain",
                tags: ["Climate", "AI", "Technology", "Mexico"],
                url: "https://example.org/climate/ai-storm-prediction",
                snippet: """
                Machine learning models now predict storm surge timing and intensity with unprecedented accuracy—but only for certain storm types. A 2025 MIT study tested five leading models against historical data and found 89% accuracy for Category 1-3 hurricanes, dropping to 61% for rapid intensification scenarios like Hurricane Otis (2024). The models excel at pattern matching but struggle with novel conditions. Still, even imperfect predictions save lives. Mexico's AI-enhanced early warning system evacuated 340,000 people from Acapulco 8 hours before Otis struck. Traditional forecasting would have provided 3-4 hours notice. "Eight hours means people can take important documents, medications, and pets," explains emergency manager Sofia Reyes.
                """
            )
        case 10:
            return SearchSnippet(
                resultID: resultID,
                index: 10,
                title: "Green Climate Fund Falls Short: Only $9.2B for Adaptation",
                tags: ["Climate", "International", "Funding", "Development"],
                url: "https://example.org/climate/green-climate-fund-shortfall",
                snippet: """
                The Green Climate Fund promised $100 billion annually for developing nation adaptation. Actual disbursements in 2024: $31.7 billion, of which only $9.2B went to adaptation (versus mitigation). Coastal cities in Bangladesh, Philippines, and Vietnam wait years for approved projects to receive funding. Meanwhile, knowledge transfer is happening through informal networks: Miami's chief resilience officer spent two weeks in Jakarta sharing lessons; Rotterdam engineers consult with Ho Chi Minh City on canal management. These peer-to-peer exchanges often prove more valuable than formal funding mechanisms. But they depend on individual initiative rather than systematic support.
                """
            )
        case _:
            return SearchSnippet(
                resultID: resultID,
                index: index,
                title: "Climate Change Policy — Source #\(index)",
                tags: ["Climate", "Resilience", "Coastal"],
                url: "https://example.org/climate/article-\(index)",
                snippet: "Climate Change Policy — Item #\(index): Coastal resilience requires integrated planning, investment, and community support."
            )
        }
    }
    
    private static func aiEducationSnippet(index: Int, resultID: UUID) -> SearchSnippet {
        switch index {
        case 1:
            return SearchSnippet(
                resultID: resultID,
                index: 1,
                title: "Parent Perspective: AI Math Tutor Boosts Grades but Raises Understanding Questions",
                tags: ["AI", "Education", "Math", "Learning", "Parent"],
                url: "https://example.org/education-ai/parent-perspective-math-tutor",
                snippet: """
                My daughter's fourth-grade teacher introduced an AI math tutor last September. At first, I was skeptical—more screen time? But here's what happened: Maya went from dreading homework to asking if she could do "extra problems." The AI adapts to her pace, celebrates small victories, never shows frustration. Her test scores improved from C+ to A- over one semester. Yet something bothers me. When I ask her to explain how she solved a problem, she sometimes can't. She knows the answer is right because "the AI checked it," but she hasn't internalized the why. Are we trading procedural fluency for genuine understanding? I honestly don't know.
                """
            )
        case 2:
            return SearchSnippet(
                resultID: resultID,
                index: 2,
                title: "The AI Divide: How Education Technology Widens Achievement Gaps",
                tags: ["AI", "Education", "Equity", "Digital Divide", "Access"],
                url: "https://example.org/education-ai/ai-divide-achievement-gaps",
                snippet: """
                The "AI divide" is already here, and it's worse than the digital divide. At least with computers and internet access, we could identify the gap and fund solutions. With AI education tools, the disparities are multidimensional: device access (premium tablets vs. hand-me-down phones), internet bandwidth (fiber vs. spotty cellular), software licenses ($15/month per student vs. free limited versions), and teacher training. Jackson Heights Elementary in Queens shares one AI-capable device cart among 18 classrooms. Nearby private schools have 1:1 AI-enhanced tablets. We're not just risking wider achievement gaps—we're guaranteeing them unless policy intervenes decisively now.
                """
            )
        case 3:
            return SearchSnippet(
                resultID: resultID,
                index: 3,
                title: "Teacher Survey: 67% Save Time with AI, But Only 31% Received Training",
                tags: ["AI", "Education", "Teachers", "Survey", "Training"],
                url: "https://example.org/education-ai/teacher-survey-2025",
                snippet: """
                Survey results from the National Education Technology Association (2025, n=4,200 teachers): 67% report AI tools save 3-5 hours weekly on lesson planning and administrative tasks. 73% feel "somewhat" or "very" confident using AI for content generation. But only 31% received formal professional development on AI integration. Most learned through YouTube tutorials, colleague recommendations, or trial-and-error. Asked about concerns, 82% cited student overreliance, 79% mentioned data privacy, 71% worried about AI perpetuating biases. The gap between adoption and preparation is striking. We're asking teachers to navigate complex ethical terrain with minimal institutional support.
                """
            )
        case 4:
            return SearchSnippet(
                resultID: resultID,
                index: 4,
                title: "Privacy Nightmare: What 'Free' AI Education Tools Really Collect",
                tags: ["AI", "Education", "Privacy", "Data", "FERPA"],
                url: "https://example.org/education-ai/privacy-concerns-data-collection",
                snippet: """
                Read the fine print on those "free" education AI tools. Most collect extensive student data: keystroke patterns, time-on-task metrics, correct/incorrect response patterns, emotional state indicators (yes, some use webcam analysis). One popular platform's privacy policy—which I actually read all 47 pages of—reserves rights to use de-identified data for algorithm improvement, sell aggregated insights to third parties, and retain data indefinitely even after account deletion. Parents can opt out, theoretically, but the process requires notarized forms submitted via postal mail. When schools adopt these tools district-wide, individual families have little practical choice. FERPA regulations haven't caught up to AI realities.
                """
            )
        case 5:
            return SearchSnippet(
                resultID: resultID,
                index: 5,
                title: "RCT Study: AI Tutoring 70% as Effective as Human Tutors at 2% the Cost",
                tags: ["AI", "Education", "Research", "Tutoring", "Economics"],
                url: "https://example.org/education-ai/rct-tutoring-effectiveness",
                snippet: """
                Randomized controlled trial (Chen et al., 2024, Journal of Educational Psychology) compared three groups of 9th-grade algebra students: traditional instruction only (n=240), traditional plus human tutoring (n=235), traditional plus AI tutoring (n=242). Results after 16 weeks: human tutoring group showed 0.73 standard deviation improvement on standardized tests; AI tutoring showed 0.51 SD improvement; control group 0.21 SD. The gap between human and AI tutoring was statistically significant (p<0.01) but the effect sizes tell a nuanced story. AI tutoring cost $8/student for the semester; human tutoring cost $340/student. For resource-constrained districts, is 70% of the benefit at 2% of the cost a good trade-off?
                """
            )
        case 6:
            return SearchSnippet(
                resultID: resultID,
                index: 6,
                title: "AI Essay Grading Matches Human Reliability But Misses Creativity",
                tags: ["AI", "Education", "Writing", "Assessment", "Grading"],
                url: "https://example.org/education-ai/essay-grading-limitations",
                snippet: """
                AI essay grading has gotten eerily good—and that's precisely the problem. I run the writing program at a large state university. Last semester, we pilot-tested an AI grading system on 500 essays, comparing its scores to three experienced instructors. Inter-rater reliability: AI-Human r=0.81, Human-Human r=0.79. The AI was as consistent with humans as humans were with each other. It identified grammar errors flawlessly, flagged weak thesis statements accurately, even commented reasonably on organizational structure. But it completely missed irony, gave top marks to superficially polished but intellectually vapid essays, and penalized creative risk-taking. We're using it for first-pass feedback on drafts, not final grades. That distinction matters.
                """
            )
        case 7:
            return SearchSnippet(
                resultID: resultID,
                index: 7,
                title: "Academic Integrity Crisis: AI Detection Tools Show 15-20% False Positives",
                tags: ["AI", "Education", "Academic Integrity", "Detection", "ESL"],
                url: "https://example.org/education-ai/academic-integrity-detection",
                snippet: """
                Academic integrity in the AI age: my inbox is full of angry emails from students who "didn't cheat" but got flagged by AI detection tools showing 73% likelihood their essay was AI-generated. They're not entirely wrong to be upset—these detection tools have false positive rates of 15-20%, higher for ESL students whose grammatically correct but stylistically distinctive writing looks "too perfect" to algorithms. Meanwhile, savvy students have learned to "humanize" AI-generated content by deliberately inserting minor errors and colloquialisms. We're locked in an arms race nobody wins. Better approach: redesign assignments to emphasize process over product, require interim drafts, incorporate in-class components that can't be outsourced to AI.
                """
            )
        case 8:
            return SearchSnippet(
                resultID: resultID,
                index: 8,
                title: "Duolingo's AI Feature: 12M Users Practice Languages, But Context Missing",
                tags: ["AI", "Education", "Language Learning", "Duolingo", "Culture"],
                url: "https://example.org/education-ai/language-learning-ai-limits",
                snippet: """
                Duolingo's AI conversation feature has 12 million active users practicing 40+ languages. I teach Spanish at a community college and have mixed feelings. On one hand, students get unlimited practice without judgment. My heritage speaker students can finally practice professional vocabulary without code-switching pressure. Students with anxiety disorders praise the low-stakes environment. Pronunciation feedback is instantaneous and accurate. But here's what the AI can't teach: the long pause before an elderly Mexican shopkeeper responds to your question about where his family is from—and the story that follows. The negotiation of meaning when someone doesn't understand and you must rephrase. The cultural context that tells you whether to use tú or usted. Language is fundamentally about human connection.
                """
            )
        case 9:
            return SearchSnippet(
                resultID: resultID,
                index: 9,
                title: "Special Education Success: Speech-to-Text AI Transforms Writing Access",
                tags: ["AI", "Education", "Special Education", "Accessibility", "ADHD"],
                url: "https://example.org/education-ai/special-ed-speech-to-text",
                snippet: """
                Special education case study: Marcus, age 8, diagnosed ADHD and dysgraphia. Traditional writing assignments = meltdowns, tears, avoidance. His IEP team introduced speech-to-text AI that converts his verbal responses into written text, which he then edits. Revelation. Marcus has rich ideas but the physical act of writing overwhelmed him. The AI tool removed that barrier. Within two months, he went from refusing to write a single paragraph to dictating elaborate stories. But—and this is critical—his special education teacher monitors constantly, ensuring he's developing editing skills, not just generation. The tool enables access; it doesn't replace instruction. We need humans in the loop, especially for our most vulnerable students.
                """
            )
        case 10:
            return SearchSnippet(
                resultID: resultID,
                index: 10,
                title: "Cognitive Offloading: How AI Learning Tools May Reshape Student Thinking",
                tags: ["AI", "Education", "Cognition", "Long-term Effects", "Research"],
                url: "https://example.org/education-ai/cognitive-offloading-concerns",
                snippet: """
                Where will this all lead? Longitudinal data won't exist for years, but we can observe leading indicators. Students who began using AI learning tools in elementary school (now in 9th grade) show patterns: strong procedural skills, weaker conceptual transfer to novel problems, less tolerance for ambiguity, tendency to seek algorithmic solutions to open-ended questions. One researcher called it "cognitive offloading"—like how GPS navigation improved efficiency but atrophied our spatial reasoning. Not inherently bad, but different. The question isn't whether to use AI in education—that ship has sailed—but rather: what cognitive abilities must we deliberately preserve and cultivate in an AI-augmented world? We haven't answered that yet.
                """
            )
        case _:
            return SearchSnippet(
                resultID: resultID,
                index: index,
                title: "AI in Education — Source #\(index)",
                tags: ["AI", "Education", "Equity"],
                url: "https://example.org/education-ai/article-\(index)",
                snippet: "AI in Education — Item #\(index): AI tools provide personalized learning while raising equity and pedagogical questions."
            )
        }
    }
    
    private static func nutritionSnippet(index: Int, resultID: UUID) -> SearchSnippet {
        switch index {
        case 1:
            return SearchSnippet(
                resultID: resultID,
                index: 1,
                title: "Blue Zones Research: Longevity Isn't About Superfoods, It's About Lifestyle",
                tags: ["Nutrition", "Longevity", "Blue Zones", "Lifestyle", "Culture"],
                url: "https://example.org/nutrition/blue-zones-lifestyle-factors",
                snippet: """
                The Blue Zones research—examining populations with exceptional longevity in Okinawa, Sardinia, Ikaria, Nicoya, and Loma Linda—reveals something unexpected: it's not really about superfoods. Okinawans eat sweet potatoes and bitter melon. Sardinians eat pecorino cheese and sourdough bread. Ikarians consume wild greens and goat's milk. The common threads? Mostly whole, unprocessed foods. Plant-dominant but not plant-exclusive. Moderate portions. But here's the part that gets overlooked: these populations eat meals with family, walk daily as transportation (not exercise), maintain strong social connections, and have lower stress. When researchers try to isolate the diet component, the longevity effects diminish. Food is inseparable from lifestyle and culture.
                """
            )
        case 2:
            return SearchSnippet(
                resultID: resultID,
                index: 2,
                title: "Caloric Restriction in Humans: CALERIE Trial Shows Mixed Results",
                tags: ["Nutrition", "Caloric Restriction", "Fasting", "Research", "CALERIE"],
                url: "https://example.org/nutrition/caloric-restriction-human-trials",
                snippet: """
                Caloric restriction (CR) extends lifespan in yeast, worms, flies, rodents—this is established science. The monkey studies were more ambiguous: one showed benefits, another didn't. The difference? Ad libitum control groups in the successful study were overfed by normal standards; the "restriction" group ate an actually appropriate amount. In humans, the CALERIE trial (phase 2, n=218, 2 years) showed CR participants lost weight (obviously), improved cardiometabolic markers, but also experienced decreased bone density, reduced muscle mass, and reported cold sensitivity, decreased libido, and lower energy. Quality of life matters. Intermittent fasting might offer middle ground—easier to maintain, possibly triggering similar autophagy pathways without constant hunger. But long-term human data doesn't exist yet.
                """
            )
        case 3:
            return SearchSnippet(
                resultID: resultID,
                index: 3,
                title: "Vitamin D and B12 Deficiency: Testing Beats Blanket Supplementation",
                tags: ["Nutrition", "Vitamins", "Supplementation", "Deficiency", "Testing"],
                url: "https://example.org/nutrition/vitamin-deficiency-testing",
                snippet: """
                Vitamin D deficiency affects an estimated 41% of U.S. adults, higher in people with darker skin and those living at northern latitudes. Low vitamin D correlates with depression, immune dysfunction, osteoporosis, and cardiovascular disease. Correlation, not necessarily causation—and that distinction matters. Multiple large RCTs found vitamin D supplementation didn't significantly reduce fractures, heart attacks, or cancer incidence in general populations. Yet severely deficient individuals clearly benefit from supplementation. B12 deficiency in older adults often stems from reduced stomach acid and intrinsic factor, not insufficient intake. Measuring actual levels before supplementing makes more sense than blanket recommendations. But testing isn't routine, and supplements are cheap, so doctors often just say "take a multivitamin."
                """
            )
        case 4:
            return SearchSnippet(
                resultID: resultID,
                index: 4,
                title: "Ultra-Processed Foods Comprise 57% of American Diet, Study Finds",
                tags: ["Nutrition", "Processed Food", "Health", "NOVA", "Obesity"],
                url: "https://example.org/nutrition/ultra-processed-food-crisis",
                snippet: """
                Ultra-processed food now comprises 57% of calories in the average American diet (NHANES data, 2024). Define ultra-processed: industrial formulations typically with five or more ingredients, often including substances never used in home cooking—modified starches, hydrogenated oils, flavor enhancers, emulsifiers, humectants. The NOVA classification system categories this stuff. What does the evidence show? Two important studies: the Brazilian cohort study (10-year follow-up, n=105,000) found each 10% increase in ultra-processed food share correlates with 14% increased mortality. The U.S. randomized crossover trial had participants eat ultra-processed vs. whole food diets (matched for calories, macro-nutrients) for two weeks each—ultra-processed group consumed 500 more calories daily and gained 2 pounds. The foods are literally engineered to promote overconsumption.
                """
            )
        case 5:
            return SearchSnippet(
                resultID: resultID,
                index: 5,
                title: "Protein and Sarcopenia: Older Adults Need 1.2-1.6g/kg Daily",
                tags: ["Nutrition", "Protein", "Aging", "Sarcopenia", "Muscle"],
                url: "https://example.org/nutrition/protein-requirements-aging",
                snippet: """
                Protein intake and sarcopenia: the evidence is actually quite strong here. Current RDA of 0.8g/kg body weight prevents deficiency but may not optimize muscle maintenance in older adults. Meta-analysis (Coelho-Júnior et al., 2024, combining 58 studies) found 1.2-1.6g/kg improved muscle mass and function in adults over 65, particularly when combined with resistance training. The amino acid leucine appears particularly important—it triggers mTOR pathway activation and muscle protein synthesis. Practical implication: a 70kg older adult should aim for 84-112g protein daily, distributed across meals (not all at dinner). Greek yogurt breakfast, chicken salad lunch, salmon dinner, plus snacks. Achievable but requires intentionality. Plant proteins can work but require larger volumes due to lower leucine content and digestibility.
                """
            )
        case 6:
            return SearchSnippet(
                resultID: resultID,
                index: 6,
                title: "Gut Microbiome Diversity: Prebiotics Beat Probiotic Supplements",
                tags: ["Nutrition", "Microbiome", "Gut Health", "Probiotics", "Fiber"],
                url: "https://example.org/nutrition/microbiome-diversity-prebiotics",
                snippet: """
                Your gut microbiome contains 100 trillion microorganisms—outnumbering human cells 10:1. But diversity has declined dramatically in industrialized populations. Hunter-gatherer societies show 2-3x greater bacterial species diversity than urban Americans. Why does this matter? Your microbiome produces neurotransmitters (90% of serotonin is made in the gut), trains your immune system, metabolizes fiber into short-chain fatty acids with anti-inflammatory properties, even influences food preferences. Probiotic supplements show disappointingly inconsistent results—most bacteria don't survive stomach acid, and even if they do, they don't typically colonize long-term. Better approach: feed the beneficial bacteria you already have with diverse fiber sources (prebiotics). Think: onions, garlic, asparagus, under-ripe bananas, oats, apples, Jerusalem artichokes. Also fermented foods: kimchi, sauerkraut, kefir, kombucha—though honestly the evidence on these is more observational than experimental.
                """
            )
        case 7:
            return SearchSnippet(
                resultID: resultID,
                index: 7,
                title: "Hydration and Cognition: Don't Wait Until You're Thirsty",
                tags: ["Nutrition", "Hydration", "Water", "Cognitive Function", "Aging"],
                url: "https://example.org/nutrition/hydration-cognitive-function",
                snippet: """
                Most people wait until they feel thirsty to drink water. Bad strategy, especially for older adults whose thirst signals are blunted. Mild dehydration (2-3% body weight) impairs cognitive function—attention, short-term memory, mood—before you feel particularly thirsty. Kidney function depends on adequate hydration for waste removal. Blood pressure regulation, body temperature control, joint lubrication—all require sufficient water. The "8 glasses a day" rule? Made up, no scientific basis. Better guideline: urine should be pale yellow. If it's dark, drink more. If it's completely clear, you might be overhydrated (rare but possible). Coffee and tea count toward hydration despite being diuretics—the fluid volume exceeds the diuretic effect. High water-content foods help too: cucumber, watermelon, oranges, soup, yogurt.
                """
            )
        case 8:
            return SearchSnippet(
                resultID: resultID,
                index: 8,
                title: "Advanced Biomarkers: LDL-P and ApoB Predict Risk Better Than Standard Tests",
                tags: ["Nutrition", "Biomarkers", "Cardiovascular", "Personalized", "Testing"],
                url: "https://example.org/nutrition/advanced-lipid-biomarkers",
                snippet: """
                Advanced lipid panels reveal more than standard cholesterol tests. LDL-P (particle count) predicts cardiovascular risk better than LDL-C (cholesterol content). You can have "normal" LDL-C with high LDL-P—many small dense particles—indicating higher risk. ApoB measures all atherogenic particles in one test. Lp(a) is genetically determined and highly predictive but rarely measured. Inflammatory markers like hsCRP, fibrinogen, and oxidized LDL indicate systemic inflammation linked to cardiovascular disease, diabetes, cancer. Continuous glucose monitors (CGMs) reveal your individual glycemic responses to foods—surprising variability between people. One person might spike from rice but not potatoes; another the reverse. This is the promise of personalized nutrition: actionable individual data. The limitation: most doctors aren't trained to interpret these advanced biomarkers, insurance often doesn't cover them, and clinical decision guidelines are still being developed.
                """
            )
        case 9:
            return SearchSnippet(
                resultID: resultID,
                index: 9,
                title: "Food Apartheid: Why 'Food Desert' Misses the Point",
                tags: ["Nutrition", "Food Access", "Equity", "Social Justice", "Policy"],
                url: "https://example.org/nutrition/food-apartheid-not-desert",
                snippet: """
                Food deserts affect 23.5 million Americans living more than 1 mile from a supermarket (10 miles in rural areas) without vehicle access. But "food desert" might be less accurate than "food apartheid"—this isn't natural geography, it's systemic disinvestment. When grocery stores leave neighborhoods, corner stores fill the gap with shelf-stable processed foods. Fresh produce is expensive, spoils quickly, and has thin profit margins. The result: limited access to affordable healthy food. Proposed solutions include tax incentives for grocery stores, mobile markets, urban agriculture, and corner store conversions. Evidence on effectiveness? Mixed. The Philadelphia Healthy Corner Store Initiative stocked produce in 600+ stores but saw minimal sales—turns out availability alone doesn't shift purchasing when processed foods are cheaper and culturally preferred. More promising: interventions addressing cost (subsidies like SNAP bonuses for produce) and cooking skills, not just availability.
                """
            )
        case 10:
            return SearchSnippet(
                resultID: resultID,
                index: 10,
                title: "Longevity Supplements: Hype Outpaces Evidence for Resveratrol, Metformin, Rapamycin",
                tags: ["Nutrition", "Longevity", "Supplements", "Geronutrition", "Research"],
                url: "https://example.org/nutrition/longevity-compounds-hype-vs-evidence",
                snippet: """
                NAD+ precursors, senolytics, metformin, rapamycin, spermidine, resveratrol—the list of potential longevity compounds grows yearly. The hype outpaces the evidence. Resveratrol extended lifespan in yeast and flies but not consistently in mammals. The doses required would mean drinking 1,000 bottles of red wine daily. Metformin shows promise beyond diabetes treatment—retrospective studies suggest metformin users have lower cancer incidence and possibly extended lifespan, but the randomized TAME trial won't report results until 2028. Rapamycin extends lifespan in mice but suppresses immune function in humans. David Sinclair takes NMN and resveratrol; Peter Attia emphasizes exercise and metabolic health; Valter Longo promotes fasting-mimicking diets. Who's right? Probably the boring answer: fundamentals matter most (sleep, exercise, stress management, social connection, avoiding smoking/excess alcohol), and the marginal gains from supplements remain speculative. But we're pattern-seeking creatures drawn to silver bullets.
                """
            )
        case _:
            return SearchSnippet(
                resultID: resultID,
                index: index,
                title: "Nutrition and Longevity — Source #\(index)",
                tags: ["Nutrition", "Aging", "Health"],
                url: "https://example.org/nutrition/article-\(index)",
                snippet: "Nutrition and Longevity — Item #\(index): Evidence links dietary patterns to health outcomes and lifespan across populations."
            )
        }
    }
    
    private static func transitSnippet(index: Int, resultID: UUID) -> SearchSnippet {
        switch index {
        case 1:
            return SearchSnippet(
                resultID: resultID,
                index: 1,
                title: "Grand Rapids' Integrated Transit System: 34% Ridership Increase in Two Years",
                tags: ["Transit", "Microtransit", "Innovation", "Grand Rapids", "Equity"],
                url: "https://example.org/transit/grand-rapids-integrated-system",
                snippet: """
                Grand Rapids, Michigan, population 198,000, launched its "Go Transit" system in 2022. Fixed-route buses on major corridors plus on-demand microtransit (think Uber but public, using 15-passenger vans) in lower-density areas. Single app handles trip planning and payment across both modes. Results after two years: 34% ridership increase, 89% user satisfaction (up from 67%), expanded service to neighborhoods that previously had no transit. Cost per ride: $8.40 (vs. $6.20 for traditional bus-only system). Worth it? Depends on your priorities. The city council is debating whether equity benefits justify the cost differential. Three council members want to expand it, two want to cut microtransit and invest in more bus routes, one is uncommitted. Public comment period closes next month.
                """
            )
        case 2:
            return SearchSnippet(
                resultID: resultID,
                index: 2,
                title: "Real-Time Transit Tracking Boosts Ridership 8-15% Without Adding Service",
                tags: ["Transit", "Technology", "Real-Time", "Apps", "User Experience"],
                url: "https://example.org/transit/real-time-tracking-impact",
                snippet: """
                I used to add 15 minutes to every transit trip to account for uncertainty. When will the bus actually arrive? The printed schedule said 8:17, but it could be 8:12 or 8:31. Now I check the real-time app: bus is 4 minutes away, currently at Highland Ave. This certainty changes behavior. Studies confirm it—perceived wait time drops even when actual wait time doesn't. Transit agencies with real-time tracking see 8-15% ridership increases. The technology isn't particularly complex: GPS on buses, cloud processing, API for apps. Cost: $50K-200K initial setup depending on fleet size, plus ongoing data/maintenance. Obstacle isn't technical; it's institutional inertia and budget allocation. Some agencies prioritize it; others spend equivalent money on printed schedules nobody trusts.
                """
            )
        case 3:
            return SearchSnippet(
                resultID: resultID,
                index: 3,
                title: "Protected Bike Lanes: Personal Story of Car-Free Commuting Success",
                tags: ["Transit", "Cycling", "Infrastructure", "Safety", "Active Transportation"],
                url: "https://example.org/transit/protected-bike-lanes-transformation",
                snippet: """
                Protected bike lanes changed my life—not an exaggeration. I live 3.8 miles from work, too close to justify driving (parking costs $180/month), too far to walk. I tried biking on regular streets: terrifying. SUVs passing 18 inches away at 40 mph, near-miss at least once a week, couldn't relax. Then the city installed protected lanes—physical barrier between cars and bikes—on my route. Suddenly cycling feels safe, even pleasant. I bike 9 months a year now. Lost 15 pounds. Save $2,000 annually on parking. The infrastructure cost $1.4M for 6.2 miles. Opponents argued it would "destroy" car traffic. Actual impact on drive times: 45-90 seconds. Bike traffic increased 412%. Four businesses on the route credit increased foot (bike) traffic for revenue growth. One café added bike parking and did $30K more revenue the first year. But the pizza place owner still complains about losing two parking spaces.
                """
            )
        case 4:
            return SearchSnippet(
                resultID: resultID,
                index: 4,
                title: "Electric Bus Fleet Economics: Lower Lifecycle Costs Despite Higher Upfront Price",
                tags: ["Transit", "Electric", "Sustainability", "Economics", "Climate"],
                url: "https://example.org/transit/electric-bus-economics",
                snippet: """
                Fleet electrification analysis, mid-sized city transit (42 buses): Diesel bus cost $450K, lasts 12 years, fuel+maintenance $75K/year = $1.35M lifecycle. Electric bus cost $750K, lasts 12 years, electricity+maintenance $38K/year = $1.21M lifecycle. The savings materialize over time but require upfront capital. Federal grants cover 80% of the premium, making this a no-brainer economically. Environmental benefits: 38 tons CO2 avoided per bus annually, plus criteria pollutants (NOx, particulates) that disproportionately affect low-income neighborhoods near bus depots. Challenges: charging infrastructure ($500K-1M depending on depot layout), cold weather range reduction (15-25% in sub-freezing temps), and driver training (regenerative braking takes adjustment). Three agencies we interviewed report high satisfaction after transitioning. One is planning to go 100% electric by 2028.
                """
            )
        case 5:
            return SearchSnippet(
                resultID: resultID,
                index: 5,
                title: "Kansas City's Fare-Free Transit: Utopian Fantasy or Practical Policy?",
                tags: ["Transit", "Fare-Free", "Equity", "Kansas City", "Policy"],
                url: "https://example.org/transit/fare-free-kansas-city",
                snippet: """
                Fare-free transit: utopian fantasy or practical policy? Kansas City, MO, went fare-free in 2020 (first major U.S. city). Ridership increased 13% first year. Revenue loss: $9M annually, replaced by dedicated sales tax. Who benefits most? Low-income residents, students, elderly—people for whom $1.50 each way creates real barriers. Efficiency gains: boarding time cut in half (no fare payment), eliminated entire fare collection infrastructure (machines, cash handling, enforcement). Downsides: some "unproductive" trips (people riding for climate-controlled shelter), occasional behavior issues. But are these bugs or features? If transit is public service like roads or libraries, why charge fares at all? The counterargument: fares provide price signals for demand, generate revenue for service expansion, and create sense of "paying customer" that comes with expectations. Albuquerque is considering it. Richmond rejected it 7-4 vote. The debate is fundamentally about what transit is for.
                """
            )
        case 6:
            return SearchSnippet(
                resultID: resultID,
                index: 6,
                title: "Transit-Oriented Development vs Transit-Proximate Displacement: A Tale of Two Cities",
                tags: ["Transit", "TOD", "Housing", "Gentrification", "Equity"],
                url: "https://example.org/transit/tod-done-right-and-wrong",
                snippet: """
                TOD done wrong: luxury condo tower next to train station, $2,400/month studio apartments, ground floor occupied by bank and Starbucks. Zero affordable housing. The existing neighborhood—working-class families, immigrant-owned businesses, Section 8 apartments—is being systematically displaced. Rents within half-mile radius increased 37% in three years following station opening. This isn't transit-oriented development; it's transit-proximate displacement. TOD done right: Minneapolis's inclusionary zoning requires 20% affordable units in any development within 1/4 mile of transit. Denver's TOD fund purchases land near stations to maintain affordability. Portland allows density increases only if developers preserve or create affordable housing. The infrastructure investment should benefit existing residents, not replace them. But implementation requires political will to constrain market forces—something many cities talk about but few actually do.
                """
            )
        case 7:
            return SearchSnippet(
                resultID: resultID,
                index: 7,
                title: "Autonomous Shuttle Reality Check: $120/Hour vs $45/Hour for Human Driver",
                tags: ["Transit", "Autonomous", "Technology", "Costs", "Pilot"],
                url: "https://example.org/transit/autonomous-shuttle-reality",
                snippet: """
                Took a ride in the autonomous shuttle pilot at Riverwalk District. Top speed: 12 mph. Route: 1.3-mile loop, seven stops. Smooth ride, honestly impressive technology. But here's what I noticed: human safety operator in driver's seat, hands hovering near controls, intervening twice in 15 minutes—once for a delivery truck double-parked, once for a pedestrian who stepped off curb unexpectedly. This is Level 3 automation at best. Operating cost: $120/hour (vehicle + 2 safety operators + remote monitoring). A human-driven shuttle costs $45/hour. The technology isn't ready, or the environment isn't ready for the technology—not sure which. Proponents say "it'll improve," and they're probably right. But we've been hearing "five years away" for a decade now. Meanwhile, that $1.2M pilot program budget could have funded 50,000 hours of human-driven bus service in underserved neighborhoods.
                """
            )
        case 8:
            return SearchSnippet(
                resultID: resultID,
                index: 8,
                title: "Portland-Vancouver Regional Transit: Eight Years to Coordinate Across State Lines",
                tags: ["Transit", "Regional", "Coordination", "Portland", "Governance"],
                url: "https://example.org/transit/regional-coordination-portland",
                snippet: """
                The Portland-Vancouver metro area spans two states (Oregon and Washington), seven counties, 25+ municipalities. For decades, transit was fragmented—TriMet in Oregon, C-TRAN in Washington, no coordination. Try using a TriMet pass on C-TRAN? Nope. Regional trip planning? Good luck. In 2019, the metro governments created the Regional Transit Coordination Authority with actual power: unified fare policy, integrated planning, joint purchasing, coordinated scheduling. It took eight years to negotiate the enabling legislation—every municipality worried about losing control. The compromise: each jurisdiction retains local service decisions but coordinates on regional routes and standards. Ridership on cross-border routes increased 48%. Operational efficiencies saved $4.3M first year. But political tension remains—suburban cities feel they subsidize urban routes; urban core argues the opposite. Collaboration is hard.
                """
            )
        case 9:
            return SearchSnippet(
                resultID: resultID,
                index: 9,
                title: "Parking Cash-Out Programs Could Double Transit Participation: Behavioral Economics",
                tags: ["Transit", "Behavioral Economics", "Employer", "Parking", "Policy"],
                url: "https://example.org/transit/parking-cashout-behavioral-economics",
                snippet: """
                My employer offers a transit pass program—they pay 75% of monthly pass cost ($60/month to me vs. $240 without). Participation rate: 23% of employees. Compare to parking, which is "free" (actually costs company $180/month per space, but invisible to employees). If they'd instead offered parking cash-out—take transit and receive $180/month parking subsidy as cash—participation would likely double based on studies from California where cash-out is required. But HR worries about tax implications and administrative complexity. This is classic behavioral economics: the default matters enormously. Most companies default to free parking, making transit the "alternative." Flip the default, outcomes change. Seattle's commute trip reduction ordinance requires large employers to offer transit incentives. Participating employers see 35-40% solo-driver rates vs. 65-75% citywide. Policy shapes behavior.
                """
            )
        case 10:
            return SearchSnippet(
                resultID: resultID,
                index: 10,
                title: "We're Measuring the Wrong Things: Transit Metrics Should Focus on Access, Not Efficiency",
                tags: ["Transit", "Metrics", "Access", "Equity", "Planning"],
                url: "https://example.org/transit/access-focused-metrics",
                snippet: """
                We're measuring the wrong things. Typical transit performance metrics: cost per passenger-mile, on-time performance, farebox recovery ratio. These optimize for efficiency, not outcomes. Alternative framework: How many residents can reach employment centers within 45 minutes? How has transit availability affected unemployment rates in disconnected neighborhoods? What's the change in household transportation costs for low-income families? The All Transit Index and similar tools map job accessibility, showing stark disparities—in some cities, low-income neighborhoods have 1/3 the job access of affluent areas despite similar population density. When Minneapolis restructured its bus network optimizing for job access rather than route efficiency, ridership increased 9% and user surveys showed 24% improvement in "meets my needs." The metrics you choose determine the system you build.
                """
            )
        case _:
            return SearchSnippet(
                resultID: resultID,
                index: index,
                title: "Urban Transit — Source #\(index)",
                tags: ["Transit", "Mobility", "Cities"],
                url: "https://example.org/transit/article-\(index)",
                snippet: "Urban Transit — Item #\(index): Agencies coordinate buses, on-demand shuttles, and safer corridors for walking and cycling."
            )
        }
    }
}

#if canImport(SwiftUI)
struct FakeSearchResultsPreview: View {
    let response = FakeSearchResults.makeResponse()
    var body: some View {
        List {
            Section("Summary") {
                Text("Scenarios: \(response.results.count) (expected 4)")
                Text("Total snippets: \(response.results.reduce(0) { $0 + $1.snippets.count }) (expected 40)")
                Text("Snippets per scenario: \(response.results.map { $0.snippets.count }.map(String.init).joined(separator: ", "))")
            }
            ForEach(Array(response.results.enumerated()), id: \.offset) { idx, result in
                Section("Scenario #\(idx + 1): \(result.query)") {
                    Text("Snippets: \(result.snippets.count)")
                    Text(result.snippets.first?.snippet.prefix(120) ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview("Fake Search Results") {
    FakeSearchResultsPreview()
}

#Preview("With Sample Data") {
    @Previewable @State var service = SearchAssistantService()
    
    VStack(spacing: 20) {
        Text("Search Assistant Demo")
            .font(.title)
        
        if service.isProcessing {
            VStack {
                ProgressView()
                Text("Processing query with Foundation Models...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        if let scenario = service.currentScenario {
            Text("Matched Scenario: \(scenario.title)")
                .font(.headline)
                .foregroundStyle(.blue)
        }
        
        if let error = service.errorMessage {
            Text("Error: \(error)")
                .foregroundStyle(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        
        if !service.aiResponse.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Response:")
                        .font(.headline)
                    
                    Text(service.aiResponse)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if !service.currentSearchResults.isEmpty {
                        Text("Sources: \(service.currentSearchResults.count) snippets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach(service.currentSearchResults.prefix(3)) { snippet in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("[\(snippet.index)] \(snippet.title)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(snippet.snippet.prefix(100) + "...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding()
            }
        }
        
        Divider()
        
        VStack(spacing: 12) {
            Text("Test Queries:")
                .font(.headline)
            
            Button("🤖 AI in Education") {
                Task {
                    print("🔍 Triggering search with query: 'AI Conversation'")
                    await service.search(query: "How does AI impact student learning and classroom dynamics?")
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("🌊 Climate Change") {
                Task {
                    print("🔍 Triggering search with query about climate")
                    await service.search(query: "What are effective climate adaptation strategies for coastal cities?")
                }
            }
            .buttonStyle(.bordered)
            
            Button("🍎 Nutrition") {
                Task {
                    print("🔍 Triggering search with query about nutrition")
                    await service.search(query: "What does research say about diet and longevity?")
                }
            }
            .buttonStyle(.bordered)
            
            Button("🚌 Urban Transit") {
                Task {
                    print("🔍 Triggering search with query about transit")
                    await service.search(query: "How can mid-sized cities improve public transportation?")
                }
            }
            .buttonStyle(.bordered)
            
            Button("Reset") {
                service.reset()
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
        }
    }
    .padding()
}
#endif

