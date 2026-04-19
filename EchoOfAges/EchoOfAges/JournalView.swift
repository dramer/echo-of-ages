// JournalView.swift
// EchoOfAges
//
// The Field Diary — displayed as a physical book with flippable pages.
// Swipe left/right to turn pages. All text uses a handwritten font.

import SwiftUI

// MARK: - Diary page type

private enum DiaryPage: Equatable {
    case frontPage
    case tableOfContents     // jump to any section
    case drMandu             // Dr. Sandra Mandu biography + Egyptian Latin Square
    case mapPage
    case tabletStory
    case tabletGrid
    case civilizations
    // One puzzle-type page per civilization (in expedition order)
    case egyptPuzzle         // Egyptian        — Latin Square
    case mesopotamiaPuzzle   // Sumerian        — Cipher
    case greecePuzzle        // Celtic / Druidic — Ogham Inscription
    case chinaPuzzle         // Ancient China   — Wooden Box
    case norsePuzzle         // Norse           — Pathfinding
    case mesoamericanPuzzle  // Maya            — Pattern / Rhythm
    case codexGlyph(Glyph)
    case greekAlphabet
    case chronicle(Int)                 // level id
    case keyDiscovery(CivilizationID)   // field note about the mystery mark found at Level 5
    case fieldNotes                     // current puzzle's clues
    case rosettaStone
    case champollionMethod
    case howToPlay
    case fieldMethods     // one illustrated card per civilization explaining its puzzle mechanic
    case howToSolve
    case inspirationPage        // Why Echo of Ages was created — tribute to Cliff Johnson
    case settingsPage
    #if DEBUG
    case gameDesignNotes        // Full gameplay design reference — DEBUG only
    #endif
}

// MARK: - Diary colors & font

private extension Color {
    static let paperCream  = Color(red: 0.93, green: 0.87, blue: 0.73)
    static let paperDark   = Color(red: 0.88, green: 0.81, blue: 0.65)
    static let inkSepia    = Color(red: 0.16, green: 0.10, blue: 0.04)
    static let inkBlue     = Color(red: 0.12, green: 0.16, blue: 0.36)
    static let inkRed      = Color(red: 0.58, green: 0.08, blue: 0.08)
    static let ruledLine   = Color(red: 0.65, green: 0.55, blue: 0.40)
    static let leatherBg   = Color(red: 0.13, green: 0.08, blue: 0.03)
}

private func handFont(_ size: CGFloat, bold: Bool = false) -> Font {
    // Scale up on iPad so text is comfortable to read without zooming
    let scale: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 1.5 : 1.0
    return .custom("BradleyHandITCTT-Bold", size: size * scale)
}

// MARK: - JournalView (The Book)

struct JournalView: View {
    @EnvironmentObject var gameState: GameState
    @State private var currentPageIndex: Int = 0

    private var pages: [DiaryPage] {
        var list: [DiaryPage] = [
            .frontPage, .tableOfContents,
            .drMandu, .mapPage, .tabletStory, .tabletGrid, .civilizations,
            .howToPlay, .fieldMethods,
            .egyptPuzzle, .mesopotamiaPuzzle, .greecePuzzle,
            .chinaPuzzle, .norsePuzzle, .mesoamericanPuzzle
        ]
        // Codex: one page per known glyph
        for glyph in gameState.codexGlyphs { list.append(.codexGlyph(glyph)) }
        list.append(.greekAlphabet)
        // Chronicle: one page per decoded level
        for levelId in gameState.decodedMessages.keys.sorted() { list.append(.chronicle(levelId)) }
        // Key discovery field notes — one per civilization whose Level 5 key has been found
        for civ in CivilizationID.allCases where gameState.discoveredKeys[civ] != nil {
            list.append(.keyDiscovery(civ))
        }
        // Field notes for current puzzle
        list.append(.fieldNotes)
        // Reference pages
        list.append(.rosettaStone)
        list.append(.champollionMethod)
        list.append(.howToSolve)
        list.append(.inspirationPage)
        list.append(.settingsPage)
        #if DEBUG
        list.append(.gameDesignNotes)
        #endif
        return list
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.leatherBg.ignoresSafeArea()

            // Leather texture vignette
            RadialGradient(
                colors: [Color(red: 0.25, green: 0.16, blue: 0.06).opacity(0.0), Color(red: 0.05, green: 0.02, blue: 0.00).opacity(0.8)],
                center: .center, startRadius: 100, endRadius: 420
            )
            .ignoresSafeArea()

            // Book pages inset so they don't underrun the header or nav bar
            GeometryReader { geo in
                TabView(selection: $currentPageIndex) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        BookPage(pageType: pages[index], pageNumber: index + 1, totalPages: pages.count, pages: pages)
                            .tag(index)
                            .environmentObject(gameState)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: geo.size.width, height: geo.size.height)
                .padding(.top, 64)
                .padding(.bottom, 52)
            }

            // Top bar sits in its own ZStack layer so PageView gestures can't swallow it
            VStack {
                diaryTopBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Color.leatherBg.ignoresSafeArea(edges: .top))
                Spacer()
                pageNav
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.leatherBg.ignoresSafeArea(edges: .bottom))
            }
        }
        .onAppear {
            if gameState.journalOpeningToSettings {
                gameState.journalOpeningToSettings = false
                if let idx = pages.firstIndex(of: .settingsPage) {
                    currentPageIndex = idx
                }
            } else if let target = gameState.journalTargetPage {
                // Explicit target page (e.g. Play button → Six Civilizations) — highest priority
                currentPageIndex = min(target, pages.count - 1)
                gameState.journalTargetPage = nil
            } else if let spotId = gameState.spotlightJournalId {
                gameState.spotlightJournalId = nil
                if let idx = pages.firstIndex(of: .chronicle(spotId)) {
                    currentPageIndex = idx
                }
            } else {
                // Restore last-viewed page
                let saved = UserDefaults.standard.integer(forKey: "EOA_journalPage")
                currentPageIndex = min(saved, pages.count - 1)
            }
        }
        .onChange(of: currentPageIndex) { _, idx in
            UserDefaults.standard.set(idx, forKey: "EOA_journalPage")
        }
        .onChange(of: gameState.journalTargetPage) { _, target in
            // Handles target page changes while the journal is already open
            if let t = target {
                currentPageIndex = min(t, pages.count - 1)
                gameState.journalTargetPage = nil
            }
        }
    }

    private var diaryTopBar: some View {
        HStack {
            Button(action: {
                HapticFeedback.tap()
                withAnimation(.easeInOut(duration: 0.35)) { gameState.closeJournal() }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Return")
                        .font(handFont(15))
                }
                .foregroundStyle(Color(red: 0.75, green: 0.60, blue: 0.35))
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.22, green: 0.14, blue: 0.06).opacity(0.9))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.50, green: 0.38, blue: 0.18).opacity(0.5), lineWidth: 0.7))
                )
            }
            Spacer()
            // Diary title
            Text("Field Diary")
                .font(handFont(20, bold: true))
                .foregroundStyle(Color(red: 0.75, green: 0.60, blue: 0.35))
            Spacer()
            Color.clear.frame(width: 72, height: 30)
        }
    }

    private var pageNav: some View {
        HStack {
            Button(action: {
                if currentPageIndex > 0 {
                    withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex -= 1 }
                    HapticFeedback.tap()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(currentPageIndex > 0
                                     ? Color(red: 0.75, green: 0.60, blue: 0.35)
                                     : Color(red: 0.35, green: 0.25, blue: 0.12))
                    .frame(width: 44, height: 36)
            }

            Spacer()

            Text("\(currentPageIndex + 1)  of  \(pages.count)")
                .font(handFont(15))
                .foregroundStyle(Color(red: 0.65, green: 0.50, blue: 0.28))

            Spacer()

            Button(action: {
                if currentPageIndex < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex += 1 }
                    HapticFeedback.tap()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(currentPageIndex < pages.count - 1
                                     ? Color(red: 0.75, green: 0.60, blue: 0.35)
                                     : Color(red: 0.35, green: 0.25, blue: 0.12))
                    .frame(width: 44, height: 36)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Book Page Wrapper

private struct BookPage: View {
    let pageType: DiaryPage
    let pageNumber: Int
    let totalPages: Int
    var pages: [DiaryPage] = []
    @EnvironmentObject var gameState: GameState

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Page background — aged paper
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.paperCream)
                .shadow(color: .black.opacity(0.45), radius: 8, x: 4, y: 4)

            // Ruled lines
            ruledLines

            // Left binding shadow
            HStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.18), Color.black.opacity(0.0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: isPad ? 32 : 22)
                Spacer()
            }
            .cornerRadius(4)

            // Page content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    pageContent
                        .padding(.leading, isPad ? 48 : 32)
                        .padding(.trailing, isPad ? 32 : 20)
                        .padding(.top, isPad ? 32 : 22)
                        .padding(.bottom, isPad ? 52 : 36)
                }
            }

            // Page number bottom-right
            Text("\(pageNumber)")
                .font(handFont(13))
                .foregroundStyle(Color.ruledLine.opacity(0.7))
                .padding(.trailing, isPad ? 24 : 16)
                .padding(.bottom, isPad ? 14 : 10)
        }
        .padding(.horizontal, isPad ? 20 : 14)
        .padding(.vertical, isPad ? 10 : 6)
    }

    @ViewBuilder
    private var ruledLines: some View {
        GeometryReader { geo in
            let lineSpacing: CGFloat = 28
            let startY: CGFloat = 50
            let lineCount = Int((geo.size.height - startY) / lineSpacing)
            ZStack {
                ForEach(0..<lineCount, id: \.self) { i in
                    Rectangle()
                        .fill(Color.ruledLine.opacity(0.18))
                        .frame(height: 0.6)
                        .frame(maxWidth: .infinity)
                        .offset(y: startY + CGFloat(i) * lineSpacing - geo.size.height / 2)
                }
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch pageType {
        case .frontPage:           FrontPageContent()
        case .tableOfContents:     TableOfContentsContent(pages: pages)
        case .drMandu:             DrManduContent()
        case .mapPage:             MapPageContent()
        case .tabletStory:         TabletStoryContent()
        case .tabletGrid:          TabletGridContent()
        case .civilizations:       CivilizationsContent()
        case .egyptPuzzle:         EgyptPuzzleContent()
        case .mesopotamiaPuzzle:   MesopotamiaPuzzleContent()
        case .greecePuzzle:        GreecePuzzleContent()
        case .chinaPuzzle:         ChinaPuzzleContent()
        case .norsePuzzle:         NorsePuzzleContent()
        case .mesoamericanPuzzle:  MesoamericanPuzzleContent()
        case .codexGlyph(let g):   CodexGlyphContent(glyph: g)
        case .greekAlphabet:       GreekAlphabetContent()
        case .chronicle(let id):       ChronicleContent(levelId: id)
        case .keyDiscovery(let civ):   KeyDiscoveryContent(civId: civ)
        case .fieldNotes:              FieldNotesContent()
        case .rosettaStone:        RosettaStoneContent()
        case .champollionMethod:   ChampollionContent()
        case .howToPlay:           HowToPlayContent()
        case .fieldMethods:        FieldMethodsContent()
        case .howToSolve:          HowToSolveContent()
        case .inspirationPage:     InspirationPageContent()
        case .settingsPage:        SettingsJournalContent()
        #if DEBUG
        case .gameDesignNotes:     GameDesignNotesContent()
        #endif
        }
    }
}

// MARK: - Page helpers

private struct HandTitle: View {
    let text: String
    var size: CGFloat = 22
    var color: Color = .inkBlue
    var body: some View {
        Text(text)
            .font(handFont(size, bold: true))
            .foregroundStyle(color)
    }
}

private struct HandBody: View {
    let text: String
    var size: CGFloat = 16
    var color: Color = .inkSepia
    var body: some View {
        Text(text)
            .font(handFont(size))
            .foregroundStyle(color)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HandNote: View {
    let text: String
    var size: CGFloat = 14
    var color: Color = Color.inkRed
    var body: some View {
        Text(text)
            .font(handFont(size))
            .foregroundStyle(color)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SectionRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.ruledLine.opacity(0.5))
            .frame(height: 1)
            .padding(.vertical, 10)
    }
}

// MARK: - Page Contents

private struct FrontPageContent: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        let name = gameState.playerName.trimmingCharacters(in: .whitespaces)
        VStack(alignment: .center, spacing: 16) {
            Spacer(minLength: 30)
            Text("𓏠")
                .font(.system(size: 48))
                .foregroundStyle(Color.inkBlue.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 10)
            Text("Field Diary")
                .font(handFont(36, bold: true))
                .foregroundStyle(Color.inkBlue)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Mandu Expedition")
                .font(handFont(20))
                .foregroundStyle(Color.inkSepia)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 20)
            Rectangle()
                .fill(Color.ruledLine.opacity(0.6))
                .frame(width: 160, height: 1)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 12)
            if name.isEmpty {
                Text("Property of the Expedition Archaeologist")
                    .font(handFont(13))
                    .foregroundStyle(Color.inkSepia.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Property of")
                    .font(handFont(13))
                    .foregroundStyle(Color.inkSepia.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(name)
                    .font(handFont(20, bold: true))
                    .foregroundStyle(Color.inkBlue.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Text("If found, do not open.")
                .font(handFont(13))
                .foregroundStyle(Color.inkRed.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 20)
            Text("2024")
                .font(handFont(18))
                .foregroundStyle(Color.inkSepia.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 40)
        }
    }
}

// MARK: - Table of Contents

private struct TableOfContentsContent: View {
    let pages: [DiaryPage]
    @EnvironmentObject var gameState: GameState

    // Fixed sections with their DiaryPage anchor and display label
    private struct TOCEntry {
        let label: String
        let icon: String
        let page: DiaryPage
    }

    private var fixedEntries: [TOCEntry] {
        [
            TOCEntry(label: "Dr. Sandra Mandu",       icon: "person.fill",          page: .drMandu),
            TOCEntry(label: "Discovery Site",         icon: "map.fill",             page: .mapPage),
            TOCEntry(label: "The Tablet of Mandu",   icon: "tablecells.fill",      page: .tabletStory),
            TOCEntry(label: "The Stone Tablet",       icon: "square.grid.3x3.fill", page: .tabletGrid),
            TOCEntry(label: "Civilizations",          icon: "globe",                page: .civilizations),
            TOCEntry(label: "How to Play",            icon: "questionmark.circle.fill", page: .howToPlay),
            TOCEntry(label: "Field Methods",          icon: "puzzlepiece.fill",         page: .fieldMethods),
            TOCEntry(label: "Field Notes",            icon: "note.text",            page: .fieldNotes),
            TOCEntry(label: "The Rosetta Stone",      icon: "doc.text.fill",        page: .rosettaStone),
            TOCEntry(label: "Champollion's Method",   icon: "text.magnifyingglass", page: .champollionMethod),
            TOCEntry(label: "How to Solve",           icon: "lightbulb.fill",       page: .howToSolve),
            TOCEntry(label: "Why Echo of Ages",       icon: "heart.text.square.fill", page: .inspirationPage),
            TOCEntry(label: "Settings",               icon: "gearshape.fill",       page: .settingsPage),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HandTitle(text: "Contents")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)

            Rectangle()
                .fill(Color.ruledLine.opacity(0.5))
                .frame(height: 1)
                .padding(.bottom, 14)

            // Fixed section entries
            ForEach(fixedEntries, id: \.label) { entry in
                if let idx = pages.firstIndex(of: entry.page) {
                    tocRow(label: entry.label, icon: entry.icon, pageNum: idx + 1) {
                        gameState.journalTargetPage = idx
                    }
                }
            }

            // Codex glyphs section
            let codexIndices = pages.enumerated().compactMap { (i, p) -> Int? in
                if case .codexGlyph = p { return i } else { return nil }
            }
            if let first = codexIndices.first {
                SectionRule()
                tocRow(label: "Codex  (\(codexIndices.count) glyphs)", icon: "character.book.closed.fill", pageNum: first + 1) {
                    gameState.journalTargetPage = first
                }
            }

            // Chronicle pages
            let chronicleIndices = pages.enumerated().compactMap { (i, p) -> Int? in
                if case .chronicle = p { return i } else { return nil }
            }
            if let first = chronicleIndices.first {
                tocRow(label: "Chronicle  (\(chronicleIndices.count) entries)", icon: "scroll.fill", pageNum: first + 1) {
                    gameState.journalTargetPage = first
                }
            }

            Spacer(minLength: 20)

            // Footer note
            Text("Tap any entry to jump to that page.")
                .font(handFont(12))
                .foregroundStyle(Color.inkSepia.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func tocRow(label: String, icon: String, pageNum: Int, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedback.tap()
            action()
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkBlue.opacity(0.7))
                    .frame(width: 18)

                Text(label)
                    .font(handFont(15))
                    .foregroundStyle(Color.inkSepia)
                    .lineLimit(1)

                // Dot leaders
                GeometryReader { geo in
                    let dots = String(repeating: ".", count: Int(geo.size.width / 5))
                    Text(dots)
                        .font(handFont(13))
                        .foregroundStyle(Color.ruledLine.opacity(0.6))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 20)

                Text("\(pageNum)")
                    .font(handFont(14))
                    .foregroundStyle(Color.inkBlue)
                    .frame(width: 28, alignment: .trailing)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }
}

private struct MapPageContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "Discovery Site")
            HandNote(text: "The island. Mid-Atlantic. It's not on any chart I've checked — and I've checked all of them.", color: Color.inkRed)
            SectionRule()
            Image("map")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.inkSepia.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
            SectionRule()
            HandBody(text: "Equidistant between South America and Africa. Six teaching tablets, each from a different ancient civilization — and beneath them, a seventh stone, partially carved, waiting to be completed.")
            Spacer(minLength: 8)
            HandNote(text: "Whatever brought objects from six civilizations to one place, we don't know it yet.", color: Color.inkSepia.opacity(0.7))
            Spacer(minLength: 4)
            HandNote(text: "Coordinates withheld pending further excavation. The team agreed.", color: Color.inkRed.opacity(0.7))
        }
    }
}

private struct TabletStoryContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "The Discovery")
            HandBody(text: "Found it on the third day. Six tablets, each carved in a different script. Egyptian hieroglyphs. Norse runes. Sumerian cuneiform. Maya glyphs. Celtic ogham. Ancient Chinese oracle script.")
            Spacer(minLength: 8)
            HandBody(text: "No civilization could have traveled to meet all the others. And yet — here they were, buried together on an island that appears on no map.")
            Spacer(minLength: 10)
            HandNote(text: "Carbon dating says the stones predate every script on them. They should not exist.", color: Color.inkRed)
            SectionRule()
            HandTitle(text: "The Partial Tablet", size: 17, color: .inkBlue)
            HandBody(text: "Beneath the six teaching tablets — half-buried in volcanic stone — we found a seventh.")
            Spacer(minLength: 8)
            HandBody(text: "Partially carved. Most of its surface is worked smooth, but six spaces were left empty. Deliberately, I think. One space for each script. As if whoever made it knew that six symbols were still missing.")
            Spacer(minLength: 10)
            HandNote(text: "The question isn't what it says. The question is: what goes in the six empty spaces?", color: Color.inkRed)
            SectionRule()
            HandTitle(text: "A Seventh Mark", size: 17, color: .inkBlue)
            HandBody(text: "When we photographed the tablet in full light, we found something we had missed. On the face of the stone — not inside any of the six empty spaces — a single mark was already carved.")
            Spacer(minLength: 8)
            HandBody(text: "It does not belong to any script we have studied. Not Egyptian. Not Norse. Not Sumerian, Maya, Celtic, or Chinese. It is not a letter, not a numeral, not a determinative. It is simply there.")
            Spacer(minLength: 10)
            HStack {
                Spacer()
                Text(TreeOfLifeKeys.ramerMark)
                    .font(.system(size: 38))
                    .foregroundStyle(Color.inkRed.opacity(0.75))
                Spacer()
            }
            Spacer(minLength: 10)
            HandNote(text: "It was carved before the six spaces were left waiting. Whoever made this tablet put it there on purpose. We do not know why. We do not know who.", color: Color.inkRed)
            SectionRule()
            HandBody(text: "The six teaching tablets are the key. Each civilization left behind five partial tablets in its own script. Solve them. Learn the patterns. The answer to what belongs in the six empty spaces is hidden inside.")
            Spacer(minLength: 8)
            HandNote(text: "The team named it the Tablet of Mandu. Nobody knows what Mandu means. We found no language it comes from.", color: Color.inkSepia.opacity(0.6))
            Spacer(minLength: 8)
            HandNote(text: "Not yet.", color: Color.inkSepia.opacity(0.45))
        }
    }
}

private struct TabletGridContent: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        let foundCount = Civilization.all.filter { gameState.discoveredKeys[$0.id] != nil }.count

        return VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "The Partial Tablet")
            HandNote(
                text: "Dr. Mandu's partially carved stone has six deliberate gaps — one for each civilization on the island. Each gap holds a symbol that does not belong to that civilization's own script.",
                color: Color.inkSepia.opacity(0.70)
            )
            SectionRule()

            HandTitle(text: "The Six Missing Symbols", size: 16, color: .inkBlue)
            HandNote(
                text: "Solve a civilization's five puzzles and the final tablet reveals a foreign mark — a symbol left by a different people. That is the missing symbol for this row.",
                color: Color.inkSepia.opacity(0.65)
            )
            Spacer(minLength: 6)

            // Six symbol slots — one per civilization
            VStack(spacing: 8) {
                ForEach(Civilization.all) { civ in
                    let key = gameState.discoveredKeys[civ.id]
                    let isFound = key != nil

                    HStack(spacing: 12) {
                        // Civilization emblem
                        Text(civ.emblem)
                            .font(.system(size: 20))
                            .foregroundStyle(isFound ? civ.accentColor : Color.inkSepia.opacity(0.22))
                            .frame(width: 28)

                        // Civilization name
                        HandBody(text: civ.name, size: 14)
                            .foregroundStyle(isFound ? Color.inkSepia.opacity(0.85) : Color.inkSepia.opacity(0.38))

                        Spacer()

                        // Symbol slot
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isFound
                                    ? civ.accentColor.opacity(0.14)
                                    : Color.paperDark.opacity(0.55))
                                .overlay(RoundedRectangle(cornerRadius: 7)
                                    .stroke(isFound
                                        ? civ.accentColor.opacity(0.55)
                                        : Color.inkSepia.opacity(0.15),
                                            lineWidth: isFound ? 1.2 : 0.6))

                            if let symbol = key {
                                Text(symbol)
                                    .font(.system(size: 22))
                                    .foregroundStyle(civ.accentColor)
                            } else {
                                Text("?")
                                    .font(handFont(18, bold: true))
                                    .foregroundStyle(Color.inkSepia.opacity(0.18))
                            }
                        }
                        .frame(width: 48, height: 48)
                    }
                }
            }

            SectionRule()

            // The Ramer mark — already on the tablet, set apart
            HandTitle(text: "Already Carved", size: 16, color: .inkRed)
            HandNote(
                text: "One mark was found on the face of the tablet itself — not in any of the six gaps, but already carved into the stone. It belongs to no known script.",
                color: Color.inkSepia.opacity(0.65)
            )
            Spacer(minLength: 4)

            HStack(spacing: 12) {
                // Empty emblem placeholder — no civilization
                Text("·")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.inkRed.opacity(0.45))
                    .frame(width: 28)

                HandBody(text: "Origin unknown", size: 14)
                    .foregroundStyle(Color.inkSepia.opacity(0.55))
                    .italic()

                Spacer()

                // Ramer mark slot — always visible, always filled
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.inkRed.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.inkRed.opacity(0.40), lineWidth: 1.0))

                    Text(TreeOfLifeKeys.ramerMark)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.inkRed.opacity(0.80))
                }
                .frame(width: 48, height: 48)
            }

            Spacer(minLength: 4)
            HandNote(
                text: "This mark was placed by whoever carved the tablet. It predates the expedition. Its meaning — and whose hand carved it — is still unknown.",
                color: Color.inkRed.opacity(0.60)
            )

            SectionRule()

            // Progress note
            if foundCount == 6 {
                HandNote(text: "All six symbols identified. The partial tablet can now be completed.", color: Color.inkBlue.opacity(0.9))
            } else {
                HandNote(
                    text: "\(foundCount) of 6 symbols identified. Complete a civilization's five puzzles to reveal its missing mark.",
                    color: foundCount > 0 ? Color.inkSepia.opacity(0.75) : Color.inkSepia.opacity(0.55)
                )
            }

            Spacer(minLength: 8)

            // Open the stone button
            Button {
                gameState.openManduTablet()
            } label: {
                HStack {
                    Spacer()
                    Text(gameState.allSixCivsComplete ? "Read the Stone" : "Open the Stone")
                        .font(handFont(16, bold: true))
                        .foregroundStyle(Color.paperCream)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.22, green: 0.16, blue: 0.06))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.65, green: 0.50, blue: 0.20), lineWidth: 1))
                        )
                    Spacer()
                }
            }
        }
    }
}

private struct CivilizationsContent: View {
    @EnvironmentObject var gameState: GameState

    private func tierLabel(for id: CivilizationID) -> String {
        switch id {
        case .egyptian:          return "Tier I — Always available"
        case .norse, .sumerian:  return "Tier II — Unlocks after Egypt"
        case .maya, .celtic:     return "Tier III — Unlocks after Norse & Sumerian"
        case .chinese:           return "Tier IV — Unlocks after Maya or Celtic"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "The Six Civilizations")
            HandBody(text: "Each civilization has five partial tablets written in its own script. Decipher all five to unlock that civilization's row on the Tablet of Mandu.")
            SectionRule()
            HandNote(text: "New civilizations unlock as you progress. Complete Egypt first, then Norse and Sumerian open together. Master those and Maya & Celtic appear. Finally: Chinese.", color: Color.inkSepia.opacity(0.65))
            SectionRule()

            ForEach(Civilization.all) { civ in
                let isDone  = gameState.civilizationsCompletedForMandu.contains(civ.id)
                let isOpen  = gameState.dynamicallyUnlockedCivIds.contains(civ.id)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(civ.emblem)
                            .font(.system(size: 18))
                            .foregroundStyle(isDone ? civ.accentColor : isOpen ? Color.inkSepia.opacity(0.65) : Color.inkSepia.opacity(0.22))
                        HandTitle(text: civ.name, size: 16,
                                  color: isDone ? Color.inkBlue : isOpen ? Color.inkSepia.opacity(0.75) : Color.inkSepia.opacity(0.35))
                        Spacer()
                        if isDone {
                            Text("✓ complete").font(handFont(12)).foregroundStyle(civ.accentColor)
                        } else if isOpen {
                            Text("in progress").font(handFont(12)).foregroundStyle(Color.inkRed.opacity(0.7))
                        } else {
                            Text("🔒 locked").font(handFont(12)).foregroundStyle(Color.inkSepia.opacity(0.30))
                        }
                    }
                    HandNote(text: civ.scriptName + "  ·  " + civ.era, size: 12,
                             color: Color.inkSepia.opacity(isDone ? 0.65 : isOpen ? 0.50 : 0.25))
                    HandNote(text: tierLabel(for: civ.id), size: 11,
                             color: isDone ? civ.accentColor.opacity(0.55) : isOpen ? Color.inkSepia.opacity(0.45) : Color.inkSepia.opacity(0.22))

                    // Play button — shown for open, incomplete civilizations
                    if isOpen && !isDone {
                        Button {
                            HapticFeedback.tap()
                            gameState.navigateToCivilization(civ.id)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11))
                                Text("Play \(civ.name)")
                                    .font(handFont(13, bold: true))
                            }
                            .foregroundStyle(Color.paperCream)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.inkSepia.opacity(0.85))
                                    .overlay(RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(red: 0.65, green: 0.50, blue: 0.20).opacity(0.6), lineWidth: 1))
                            )
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
                if civ.id != .chinese {
                    Rectangle().fill(Color.ruledLine.opacity(0.25)).frame(height: 0.5)
                }
            }
        }
    }
}

private struct CodexGlyphContent: View {
    let glyph: Glyph

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "Codex Entry")
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.paperDark)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.inkSepia.opacity(0.3), lineWidth: 1))
                    Text(glyph.rawValue).font(.system(size: 52)).foregroundStyle(Color.inkBlue)
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: glyph.displayName, size: 20, color: .inkBlue)
                    HandNote(text: glyph.meaning, size: 14, color: Color.inkSepia.opacity(0.75))
                    HandNote(text: "Sound: /\(glyph.glyphTransliteration)/", size: 13, color: Color.inkSepia.opacity(0.55))
                }
            }
            SectionRule()
            HandTitle(text: "Field Notes", size: 16)
            HandBody(text: glyph.discoveryNote)
        }
    }
}

private extension Glyph {
    var glyphTransliteration: String {
        switch self {
        case .eye:   return "ḥr"
        case .owl:   return "m"
        case .water: return "n"
        case .lion:  return "rw"
        case .sky:   return "pt"
        }
    }
}

private struct GreekAlphabetContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "Greek Alphabet")
            HandBody(text: "The Rosetta Stone was cracked because scholars knew Greek. I'm keeping this reference here — same reason.")
            HandNote(text: "Cross-reference anything you can't identify.", color: Color.inkRed.opacity(0.7))
            SectionRule()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 6) {
                ForEach(GreekLetter.alphabet) { letter in
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Text(letter.upper).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.inkBlue)
                            Text(letter.lower).font(.system(size: 13)).foregroundStyle(Color.inkSepia.opacity(0.8))
                        }
                        Text(letter.name).font(handFont(10)).foregroundStyle(Color.inkSepia.opacity(0.65))
                        Text("/\(letter.sound)/").font(handFont(10)).foregroundStyle(Color.inkSepia.opacity(0.45))
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.paperDark.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ruledLine.opacity(0.4), lineWidth: 0.5)))
                }
            }
        }
    }
}

private struct ChronicleContent: View {
    let levelId: Int
    @EnvironmentObject var gameState: GameState

    var body: some View {
        let level = Level.allLevels.first(where: { $0.id == levelId })
        let message = gameState.decodedMessages[levelId]

        VStack(alignment: .leading, spacing: 14) {
            if let level = level {
                HandTitle(text: "Decoded — \(level.title)")
                HandNote(text: "Partial Tablet \(level.romanNumeral)  ·  Egyptian Hieroglyphics", color: Color.inkSepia.opacity(0.6))
                SectionRule()
                if let msg = message {
                    HandBody(text: msg)
                }
                SectionRule()
                HandTitle(text: "Scholar's Notes", size: 16)
                HandBody(text: level.journalEntry.body, size: 15)
            }
        }
    }
}

// MARK: - Key Discovery Content

private struct KeyDiscoveryContent: View {
    let civId: CivilizationID
    @EnvironmentObject var gameState: GameState

    private var civ: Civilization? { Civilization.all.first { $0.id == civId } }

    var body: some View {
        let title = TreeOfLifeKeys.keyDiscoveryTitle(for: civId)
        let body  = TreeOfLifeKeys.keyDiscoveryBody(for: civId)
        // Egypt produced TWO marks — the Djed (𓊽) and the Neter (𓊹).
        // All other civs produced exactly one.
        let isEgypt   = civId == .egyptian
        let symbol1   = TreeOfLifeKeys.produced(by: civId) ?? "?"
        let symbol2   = isEgypt ? TreeOfLifeKeys.egyptNeter : nil

        VStack(alignment: .leading, spacing: 14) {
            // Section stamp
            HStack(spacing: 8) {
                Text(civ?.emblem ?? "")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.inkSepia.opacity(0.55))
                HandNote(text: (civ?.name ?? "").uppercased() + "  ·  FIELD DISCOVERY",
                         color: Color.inkSepia.opacity(0.55))
            }

            SectionRule()

            // Symbol display — one mark for most civs, two for Egypt
            HStack {
                Spacer()
                if let s2 = symbol2 {
                    // Egypt: show both marks side by side with individual captions
                    HStack(spacing: 32) {
                        VStack(spacing: 6) {
                            Text(symbol1)
                                .font(.system(size: 52))
                                .foregroundStyle(Color.inkSepia.opacity(0.75))
                            Text("— first mark —")
                                .font(handFont(12))
                                .foregroundStyle(Color.inkSepia.opacity(0.38))
                        }
                        VStack(spacing: 6) {
                            Text(s2)
                                .font(.system(size: 52))
                                .foregroundStyle(Color.inkSepia.opacity(0.75))
                            Text("— second mark —")
                                .font(handFont(12))
                                .foregroundStyle(Color.inkSepia.opacity(0.38))
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        Text(symbol1)
                            .font(.system(size: 52))
                            .foregroundStyle(Color.inkSepia.opacity(0.75))
                        Text("— the mark —")
                            .font(handFont(13))
                            .foregroundStyle(Color.inkSepia.opacity(0.38))
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)

            SectionRule()

            HandTitle(text: title)
            HandBody(text: body)

            SectionRule()

            // Closing note — plural for Egypt, singular for everyone else
            HandNote(
                text: isEgypt
                    ? "Both marks were found among the ruins. Neither belongs to Egypt's known script."
                    : "This mark was found among the ruins. It does not belong to this civilization's known script.",
                color: Color.inkBlue.opacity(0.65)
            )
        }
    }
}

private struct FieldNotesContent: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        let level = gameState.currentLevel

        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "Field Notes")
            HandNote(text: "\(level.title)  ·  Chamber \(level.romanNumeral)", color: Color.inkSepia.opacity(0.6))
            SectionRule()
            HandBody(text: level.lore, size: 15)
            SectionRule()

            let acrostic = TreeOfLifeKeys.acrosticLetter(for: .egyptian, levelIndex: gameState.currentLevelIndex)
            ForEach(Array(level.inscriptions.enumerated()), id: \.offset) { i, note in
                HStack(alignment: .top, spacing: 10) {
                    Text("—")
                        .font(handFont(20))
                        .foregroundStyle(Color.inkRed.opacity(0.7))
                    Text(acrosticUnderlined(note, letter: acrostic))
                        .font(handFont(20))
                        .foregroundStyle(Color.inkSepia)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if i < level.inscriptions.count - 1 {
                    Spacer(minLength: 4)
                }
            }
        }
    }
}

private struct RosettaStoneContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "The Rosetta Stone, 1799")
            HandNote(text: "French soldiers found it near Rosetta, Egypt. We found our equivalent in the Atlantic.", color: Color.inkRed.opacity(0.7))
            SectionRule()
            HandBody(text: "The Rosetta Stone carried the same royal decree in three scripts — formal hieroglyphs at the top, everyday Egyptian (Demotic) in the middle, Ancient Greek at the bottom.")
            Spacer(minLength: 6)
            HandBody(text: "Scholars already knew Greek. That was the key. By matching Greek words to their hieroglyph equivalents, they found their first anchor points.")
            SectionRule()
            HandNote(text: "The partial tablets around the Tablet of Mandu are our Rosetta Stones. Each one is written in a single, pure script. Decipher them first. Then apply what you learn to the main tablet.", color: Color.inkBlue.opacity(0.85))
        }
    }
}

private struct ChampollionContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "Champollion's Method, 1822")
            HandBody(text: "Jean-François Champollion spent years on the Rosetta Stone before his breakthrough. His method:")
            SectionRule()
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text("1.")
                        .font(handFont(15, bold: true))
                        .foregroundStyle(Color.inkBlue)
                        .frame(width: 22, alignment: .leading)
                    HandBody(text: "Find anchor points — symbols you already know. Build outward from certainty, never from guesswork.")
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("2.")
                        .font(handFont(15, bold: true))
                        .foregroundStyle(Color.inkBlue)
                        .frame(width: 22, alignment: .leading)
                    HandBody(text: "Find the cartouches — oval frames around royal names. Names are phonetic. From one name, you learn multiple sounds.")
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("3.")
                        .font(handFont(15, bold: true))
                        .foregroundStyle(Color.inkBlue)
                        .frame(width: 22, alignment: .leading)
                    HandBody(text: "Use determinatives — the context symbols at the end of words. They tell you the category of meaning without spelling it out.")
                }
            }
            SectionRule()
            HandNote(text: "Each certain symbol revealed two more. The cipher cascaded open.", color: Color.inkRed.opacity(0.8))
        }
    }
}

// MARK: - How to Play Page

private struct HowToPlayContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            HandTitle(text: "How to Play")
            HandBody(text: "Dr. Mandu found a partially carved stone with six empty spaces — one for each ancient civilization. Solve each civilization's teaching tablets to discover which symbol belongs in its empty space.")

            SectionRule()

            // Step 1
            HStack(alignment: .top, spacing: 10) {
                Text("I").font(handFont(15, bold: true)).foregroundStyle(Color.inkRed).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "Start with Egypt", size: 15, color: .inkBlue)
                    HandBody(text: "Egypt's five teaching tablets use hieroglyphs arranged in a grid — no symbol repeats in any row or column. Solve all five and a symbol will be identified for Egypt's empty space on the partial stone.", size: 14)
                }
            }

            SectionRule()

            // Step 2
            HStack(alignment: .top, spacing: 10) {
                Text("II").font(handFont(15, bold: true)).foregroundStyle(Color.inkRed).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "Norse & Sumerian Unlock Together", size: 15, color: .inkBlue)
                    HandBody(text: "Complete Egypt and two new civilizations open: Norse runes (a pathfinding puzzle) and Sumerian cuneiform (a substitution cipher). Solve both to identify their missing symbols.", size: 14)
                    HandNote(text: "You can play Norse and Sumerian in any order.", size: 12, color: Color.inkSepia.opacity(0.6))
                }
            }

            SectionRule()

            // Step 3
            HStack(alignment: .top, spacing: 10) {
                Text("III").font(handFont(15, bold: true)).foregroundStyle(Color.inkRed).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "Maya & Celtic Follow", size: 15, color: .inkBlue)
                    HandBody(text: "Finish both Norse and Sumerian and Maya glyphs and Celtic ogham unlock. Complete either one to reveal the sixth and final civilization.", size: 14)
                }
            }

            SectionRule()

            // Step 4
            HStack(alignment: .top, spacing: 10) {
                Text("IV").font(handFont(15, bold: true)).foregroundStyle(Color.inkRed).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "Chinese Oracle Script", size: 15, color: .inkBlue)
                    HandBody(text: "Complete Maya or Celtic and the last civilization unlocks: ancient Chinese oracle bone script. Solve all five tablets to identify the sixth and final missing symbol.", size: 14)
                }
            }

            SectionRule()

            // The Partial Stone
            HStack(alignment: .top, spacing: 10) {
                Text("𓇳").font(.system(size: 15)).foregroundStyle(Color(red: 0.60, green: 0.42, blue: 0.10)).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "Complete the Partial Stone", size: 15, color: .inkBlue)
                    HandBody(text: "Once all six symbols are identified, return to the Tablet of Mandu. Place each civilization's symbol in its empty space. All six must be correct for the stone to hold them.", size: 14)
                    Spacer(minLength: 4)
                    HandNote(text: "The symbols fall away when you close the stone — until all six civilizations are fully solved. Then they are held in place forever.", size: 13, color: Color.inkRed.opacity(0.75))
                }
            }
        }
    }
}

// MARK: - Field Methods Page (one illustrated card per civilization)

private struct FieldMethodsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HandTitle(text: "Field Methods")
            HandBody(text: "Each civilization sealed its knowledge in a different form. Six sites. Six puzzles. The rules are not written on the walls — they must be discovered.", size: 14)
            Spacer(minLength: 12)

            VStack(spacing: 10) {
                MethodCard(
                    emblem: "𓂀",
                    civilization: "Egypt — The Inscription Grid",
                    mechanic: "Latin square",
                    description: "A stone tablet divided into rows and columns. Each hieroglyph appears exactly once in every row and once in every column. Some cells are already carved. The rest must be deduced — no guessing required.",
                    accentColor: Color(red: 0.72, green: 0.52, blue: 0.18)
                )
                MethodCard(
                    emblem: "ᚠ",
                    civilization: "Norse — The Runestone Path",
                    mechanic: "Pathfinding maze",
                    description: "A grid of cells. Find the single unbroken path from start to finish that visits every cell exactly once. Tap cells to draw the route. Long-press to erase a step.",
                    accentColor: Color(red: 0.40, green: 0.55, blue: 0.80)
                )
                MethodCard(
                    emblem: "𒀭",
                    civilization: "Sumerian — The Cipher Tablet",
                    mechanic: "Substitution cipher",
                    description: "Cuneiform signs stand in for hidden symbols. Clue tablets reveal which signs are truthful and which deceive. Use logic to eliminate — the correct reading is the only one that doesn't contradict itself.",
                    accentColor: Color(red: 0.70, green: 0.48, blue: 0.22)
                )
                MethodCard(
                    emblem: "☽",
                    civilization: "Maya — The Calendar Wheels",
                    mechanic: "Rotating wheel alignment",
                    description: "Three interlocking calendar rings. Each ring holds a sequence of symbols. Rotate the rings until the symbols align correctly in the reading window — the Long Count does not forgive partial answers.",
                    accentColor: Color(red: 0.40, green: 0.65, blue: 0.42)
                )
                MethodCard(
                    emblem: "ᚅ",
                    civilization: "Celtic — The Ogham Stones",
                    mechanic: "Sequence ordering",
                    description: "Sacred Ogham marks must be placed in the correct ceremonial order. The inscriptions on each stone hold the clue — read them carefully. The grove remembers the right arrangement.",
                    accentColor: Color(red: 0.35, green: 0.52, blue: 0.28)
                )
                MethodCard(
                    emblem: "木",
                    civilization: "China — The Wooden Tray",
                    mechanic: "Tangram / fitting puzzle",
                    description: "Carved wooden pieces must fill the lacquered tray exactly — no gaps, no overlaps. Each piece can be rotated. Drag from the palette onto the board. Two pieces carry marks from other lands.",
                    accentColor: Color(red: 0.72, green: 0.24, blue: 0.14)
                )
            }
        }
    }
}

private struct MethodCard: View {
    let emblem: String
    let civilization: String
    let mechanic: String
    let description: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Emblem column
            VStack(spacing: 4) {
                Text(emblem)
                    .font(.system(size: 26))
                    .foregroundStyle(accentColor)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accentColor.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(accentColor.opacity(0.35), lineWidth: 1)
                            )
                    )
                Text(mechanic)
                    .font(handFont(8))
                    .foregroundStyle(accentColor.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .frame(width: 52)
            }

            // Text column
            VStack(alignment: .leading, spacing: 3) {
                Text(civilization)
                    .font(handFont(13, bold: true))
                    .foregroundStyle(Color.inkBlue)
                Text(description)
                    .font(handFont(12))
                    .foregroundStyle(Color.inkSepia.opacity(0.85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.paperDark.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentColor.opacity(0.25), lineWidth: 0.8)
                )
        )
    }
}

// MARK: - Inspiration / Tribute Page

private struct InspirationPageContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Title
            HandTitle(text: "Why I Built This")
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 6)
            HandNote(text: "A personal note from the developer.", size: 13,
                     color: Color.inkSepia.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .center)

            SectionRule()

            HandTitle(text: "A Tribute to Cliff Johnson", size: 18, color: .inkBlue)
            Spacer(minLength: 10)

            // Image floated right alongside first paragraph
            HStack(alignment: .top, spacing: 10) {
                HandBody(text: "In 1987 a game arrived on the Macintosh that captured someone very close to me completely. The Fool's Errand was unlike anything they had encountered — a world woven entirely out of puzzles, where tarot cards, word games, mazes, and logic grids were not obstacles between story beats but the story itself. Every solved puzzle was a sentence in a larger sentence. Cliff Johnson had conjured a cathedral from monochrome pixels on a nine-inch screen — assembled from nothing but bits and bytes — and watching someone I loved walk through every room of it planted something in me.")

                VStack(spacing: 4) {
                    Image("fools_errand")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.inkSepia.opacity(0.35), lineWidth: 1))
                        .shadow(color: .black.opacity(0.22), radius: 3, x: 1, y: 2)
                    Text("The Fool's Errand\nCliff Johnson, 1987")
                        .font(handFont(10))
                        .foregroundStyle(Color.inkSepia.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .frame(width: 86)
                }
            }

            Spacer(minLength: 12)
            HandBody(text: "I was finding my footing as a software developer then, working at Intuit with a remarkable team on the Macintosh version of Quicken. It was the early days of the Mac — small tight teams, every line of code mattered, and the machine itself felt like a living thing. We cared deeply about the craft. But that question — what would it feel like to build something like The Fool's Errand? — never left me.")

            SectionRule()

            HandTitle(text: "Kings in the Corner", size: 18, color: .inkBlue)
            Spacer(minLength: 10)
            HandBody(text: "Years later I started building games of my own. First came Kings in the Corner — a classic card game I turned into a web app, just to see if I could. People played it. More people found it. When the pandemic arrived and the world went quiet, I turned it into a proper iOS app. Suddenly there was time to build something real, and an audience that needed something to do.")
            Spacer(minLength: 12)
            HandBody(text: "That experience taught me the whole shape of it — design, code, polish, ship. And it reminded me that the question from 1987 was still sitting there, unanswered.")

            SectionRule()

            HandTitle(text: "Echo of Ages", size: 18, color: .inkBlue)
            Spacer(minLength: 10)
            HandBody(text: "This is where that question leads. Six ancient civilizations, each one hiding its knowledge inside a different kind of puzzle. A stone tablet that only reveals itself when every voice has been heard. A journey that rewards patience, not reflexes — exactly the kind of game that family member fell in love with all those years ago.")
            Spacer(minLength: 12)
            HandBody(text: "Cliff Johnson never knew his game would travel this far. This one is for him — and for the person who showed me why it mattered.")
            Spacer(minLength: 12)

            // Signature
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("— D.R.")
                        .font(handFont(18, bold: true))
                        .foregroundStyle(Color.inkBlue)
                    Text("Expedition Archaeologist")
                        .font(handFont(13))
                        .foregroundStyle(Color.inkSepia.opacity(0.55))
                }
            }

            Spacer(minLength: 20)
        }
    }
}

// MARK: - Settings Journal Page

private struct SettingsJournalContent: View {
    @EnvironmentObject var gameState: GameState
    @Environment(SoundManager.self) var soundManager
    @State private var confirmingReset: CivilizationID? = nil
    @State private var confirmingResetAll = false
    @State private var editingName = false
    @State private var nameInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "Expedition Settings")
            HandNote(text: "Field notes on how to configure your expedition.", color: Color.inkSepia.opacity(0.55))
            SectionRule()

            // Archaeologist Name
            HandTitle(text: "Archaeologist", size: 17, color: .inkBlue)
            Spacer(minLength: 2)

            if editingName {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Enter your name", text: $nameInput)
                        .font(handFont(15, bold: true))
                        .foregroundStyle(Color.inkSepia)
                        .tint(Color.inkBlue)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.paperCream)
                                .overlay(RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.inkSepia.opacity(0.35), lineWidth: 1))
                        )
                        .onSubmit { commitNameEdit() }

                    HStack(spacing: 14) {
                        Button(action: commitNameEdit) {
                            Text("Save")
                                .font(handFont(13, bold: true))
                                .foregroundStyle(nameInput.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.inkBlue.opacity(0.35)
                                    : Color.inkBlue)
                        }
                        .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button(action: { withAnimation { editingName = false } }) {
                            Text("Cancel")
                                .font(handFont(13, bold: false))
                                .foregroundStyle(Color.inkSepia.opacity(0.6))
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HandBody(text: "Name", size: 15)
                        HandNote(
                            text: gameState.playerName.isEmpty ? "Not set" : gameState.playerName,
                            size: 13,
                            color: gameState.playerName.isEmpty
                                ? Color.inkSepia.opacity(0.45)
                                : Color.inkSepia.opacity(0.85)
                        )
                    }
                    Spacer()
                    Button(action: {
                        HapticFeedback.tap()
                        nameInput = gameState.playerName
                        withAnimation { editingName = true }
                    }) {
                        Text(gameState.playerName.isEmpty ? "Set Name" : "Edit")
                            .font(handFont(13, bold: true))
                            .foregroundStyle(Color.inkBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.paperDark)
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.inkSepia.opacity(0.25), lineWidth: 1))
                            )
                    }
                }
            }

            SectionRule()

            // Introduction
            HandTitle(text: "Introduction", size: 17, color: .inkBlue)
            Spacer(minLength: 2)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HandBody(text: "Show on launch", size: 15)
                    HandNote(text: "Play the opening story each time the app starts.", size: 12, color: Color.inkSepia.opacity(0.55))
                }
                Spacer()
                Toggle("", isOn: $gameState.showIntroOnLaunch)
                    .labelsHidden()
                    .toggleStyle(GreenRedToggleStyle())
                    .onChange(of: gameState.showIntroOnLaunch) { _, _ in gameState.saveSettings() }
            }
            Spacer(minLength: 4)
            Button {
                HapticFeedback.tap()
                gameState.closeJournal()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    gameState.playIntro()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill").font(.system(size: 16))
                    Text("Watch Introduction Again").font(handFont(14, bold: true))
                }
                .foregroundStyle(Color.inkBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.paperDark)
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.inkSepia.opacity(0.25), lineWidth: 1))
                )
            }

            SectionRule()

            // Sound
            soundSection

            SectionRule()

            // Haptics
            hapticsSection

            SectionRule()

            // Reset progress
            HandTitle(text: "Reset Progress", size: 17, color: .inkBlue)
            HandNote(text: "Erasing a civilization removes all solved puzzles and decoded messages for that culture.", size: 12, color: Color.inkSepia.opacity(0.55))
            Spacer(minLength: 6)

            VStack(spacing: 8) {
                ForEach(Civilization.all.filter { $0.isUnlocked }) { civ in
                    let hasProg = gameState.civilizationsCompletedForMandu.contains(civ.id) ||
                                  (civ.id == .egyptian && !gameState.unlockedJournalEntries.isEmpty) ||
                                  (civ.id == .norse && !gameState.norseUnlockedLevels.isEmpty) ||
                                  (civ.id == .sumerian && !gameState.sumerianUnlockedLevels.isEmpty)
                    HStack(spacing: 10) {
                        Text(civ.emblem).font(.system(size: 20))
                        HandBody(text: civ.name, size: 14)
                        Spacer()
                        if hasProg {
                            Button {
                                HapticFeedback.tap()
                                confirmingReset = civ.id
                            } label: {
                                Text("Reset")
                                    .font(handFont(13, bold: true))
                                    .foregroundStyle(Color.inkRed)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.inkRed.opacity(0.08))
                                            .overlay(RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color.inkRed.opacity(0.30), lineWidth: 1))
                                    )
                            }
                        } else {
                            HandNote(text: "no progress", size: 12, color: Color.inkSepia.opacity(0.35))
                        }
                    }
                }
            }

            Spacer(minLength: 4)
            Button {
                HapticFeedback.heavy()
                confirmingResetAll = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 14))
                    Text("Reset All Progress").font(handFont(13, bold: true))
                }
                .foregroundStyle(Color.inkRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.inkRed.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.inkRed.opacity(0.30), lineWidth: 1))
                )
            }

            SectionRule()

            // Debug — only visible in DEBUG builds
            #if DEBUG
            HandTitle(text: "Developer", size: 17, color: .inkBlue)
            HandNote(text: "Jump to any puzzle, mark levels solved, and test all civilizations.", size: 12, color: Color.inkSepia.opacity(0.55))
            Spacer(minLength: 6)
            Button {
                HapticFeedback.tap()
                gameState.openDebug()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ladybug.fill").font(.system(size: 16))
                    Text("Open Puzzle Debug Panel").font(handFont(14, bold: true))
                }
                .foregroundStyle(Color(red: 0.10, green: 0.35, blue: 0.60))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(red: 0.10, green: 0.28, blue: 0.55).opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(red: 0.10, green: 0.35, blue: 0.60).opacity(0.40), lineWidth: 1))
                )
            }
            SectionRule()
            #endif

            // Version
            HandTitle(text: "About", size: 17, color: .inkBlue)
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
            let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
            HStack { HandBody(text: "Echo of Ages", size: 14); Spacer() }
            HStack {
                HandNote(text: "Version \(version)  ·  Build \(build)", size: 12, color: Color.inkSepia.opacity(0.55))
                Spacer()
            }
        }
        .confirmationDialog("Reset \(confirmingReset.flatMap { id in Civilization.all.first { $0.id == id }?.name } ?? "")?",
                            isPresented: Binding(get: { confirmingReset != nil }, set: { if !$0 { confirmingReset = nil } }),
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                if let id = confirmingReset { gameState.resetCivilization(id) }
                confirmingReset = nil
            }
            Button("Cancel", role: .cancel) { confirmingReset = nil }
        }
        .confirmationDialog("Reset all expedition progress?", isPresented: $confirmingResetAll, titleVisibility: .visible) {
            Button("Reset Everything", role: .destructive) {
                for civ in Civilization.all where civ.isUnlocked { gameState.resetCivilization(civ.id) }
                UserDefaults.standard.removeObject(forKey: "EOA_hasSeenIntro")
                HapticFeedback.heavy()
                confirmingResetAll = false
            }
            Button("Cancel", role: .cancel) { confirmingResetAll = false }
        }
    }

    private func commitNameEdit() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        HapticFeedback.tap()
        gameState.savePlayerName(trimmed)
        withAnimation { editingName = false }
    }

    // MARK: - Sound section

    @ViewBuilder
    private var soundSection: some View {
        @Bindable var sm = soundManager

        HandTitle(text: "Sound", size: 17, color: .inkBlue)
        HandNote(text: "Background music plays softly while you solve each inscription.", size: 12, color: Color.inkSepia.opacity(0.55))
        Spacer(minLength: 6)

        // Master toggle
        soundRow(icon: sm.masterEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill",
                 label: sm.masterEnabled ? "All Sound — On" : "All Sound — Off",
                 isOn: $sm.masterEnabled)

        Spacer(minLength: 4)

        // Per-civilization + diary (dimmed when master is off)
        VStack(spacing: 6) {
            soundRow(icon: "𓂀",  label: "Egyptian",    isOn: $sm.egyptEnabled,    sfSymbol: false)
            soundRow(icon: "ᚱ",   label: "Norse",       isOn: $sm.norseEnabled,    sfSymbol: false)
            soundRow(icon: "𒀭",  label: "Sumerian",    isOn: $sm.sumerianEnabled, sfSymbol: false)
            soundRow(icon: "🌿",  label: "Maya",        isOn: $sm.mayaEnabled,     sfSymbol: false)
            soundRow(icon: "ᚁ",   label: "Celtic",      isOn: $sm.celticEnabled,   sfSymbol: false)
            soundRow(icon: "☰",   label: "Chinese",     isOn: $sm.chineseEnabled,  sfSymbol: false)
            soundRow(icon: "book.fill", label: "Field Diary", isOn: $sm.journalEnabled)
        }
        .disabled(!sm.masterEnabled)
        .opacity(sm.masterEnabled ? 1.0 : 0.38)
        .animation(.easeInOut(duration: 0.2), value: sm.masterEnabled)
    }

    // MARK: - Haptics section

    @ViewBuilder
    private var hapticsSection: some View {
        @Bindable var sm = soundManager

        HandTitle(text: "Haptics & Move Sounds", size: 17, color: .inkBlue)
        HandNote(text: "Action feedback on taps, placements, errors, and puzzle solves.", size: 12, color: Color.inkSepia.opacity(0.55))
        Spacer(minLength: 6)
        soundRow(icon: "hand.tap.fill",        label: "Gameplay Haptics", isOn: $sm.hapticsEnabled)
        soundRow(icon: "waveform.circle.fill", label: "Move Sounds",      isOn: $sm.effectsEnabled)
    }

    // MARK: - Shared toggle row (diary style)

    private func soundRow(
        icon: String,
        label: String,
        isOn: Binding<Bool>,
        sfSymbol: Bool = true
    ) -> some View {
        HStack(spacing: 10) {
            Group {
                if sfSymbol {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .frame(width: 22)
                } else {
                    Text(icon)
                        .font(.system(size: 16))
                        .frame(width: 22)
                }
            }
            .foregroundStyle(Color.inkSepia.opacity(0.70))

            HandBody(text: label, size: 14)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(GreenRedToggleStyle())
        }
    }
}

private struct HowToSolveContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "How to Read the Partial Tablets")
            HandBody(text: "The partial tablets follow one grammatical rule the Egyptians held sacred: no sacred symbol may appear twice in any line of an inscription — horizontal or vertical.")
            SectionRule()
            HandBody(text: "The darker cells are fixed — carved stone, readable without effort. These are your anchor points. Begin there.")
            Spacer(minLength: 4)
            HandBody(text: "From each anchor, ask: what can go in the cells that share its row? Its column? The answers eliminate positions until only one remains.")
            SectionRule()
            HandNote(text: "When stuck: don't guess. List only what is certain. Each truth reveals the next. This is how Champollion did it. It is the only way.", color: Color.inkBlue.opacity(0.85))
            Spacer(minLength: 8)
            HandNote(text: "Use the Known Glyphs panel in the puzzle screen to reference your codex without leaving the inscription.", color: Color.inkSepia.opacity(0.6))
        }
    }
}

// MARK: - Dr. Mandu Biography Page

private struct DrManduContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Page title
            HandTitle(text: "Dr. Sandra Mandu", size: 26, color: .inkBlue)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)

            Text("Lead Archaeologist — Mandu Expedition")
                .font(handFont(13))
                .foregroundStyle(Color.inkSepia.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 16)

            SectionRule()

            // Photo — uses the 'mandu' image asset
            if UIImage(named: "mandu") != nil {
                Image("mandu")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.ruledLine.opacity(0.6), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 5, x: 2, y: 3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 6)

                Text("Dr. Sandra Mandu, 2024")
                    .font(handFont(11))
                    .foregroundStyle(Color.inkSepia.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 16)
            }

            SectionRule()

            // Biography
            HandBody(text: "Dr. Sandra Mandu is one of the world's foremost authorities on ancient writing systems and cross-cultural linguistics. With her signature thick-framed glasses and an unnerving ability to read a room — or a ruin — she has led excavations on four continents.")

            Spacer(minLength: 14)

            HandBody(text: "Born in New Jersey, in the shadow of Thomas Edison's old laboratory complex in Menlo Park, Sandra grew up surrounded by a family that treated invention as a way of life. From her earliest years she had a deep love of books — she could be found reading in every spare moment, working through her local library shelf by shelf. She displayed an obsession with pattern and language from an early age, and taught herself Ancient Greek at fourteen using library books and stubbornness in equal measure.")

            Spacer(minLength: 14)

            SectionRule()

            HandTitle(text: "Education", size: 17, color: .inkBlue)
                .padding(.bottom, 6)

            HStack(alignment: .top, spacing: 10) {
                Text("𓏲").font(.system(size: 14)).foregroundStyle(Color.inkRed)
                VStack(alignment: .leading, spacing: 2) {
                    HandBody(text: "B.A. Linguistics & Classical Studies", size: 14)
                    HandNote(text: "Rice University, Houston  ·  Magna Cum Laude", size: 12, color: Color.inkSepia.opacity(0.65))
                }
            }
            .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 10) {
                Text("𓏲").font(.system(size: 14)).foregroundStyle(Color.inkRed)
                VStack(alignment: .leading, spacing: 2) {
                    HandBody(text: "Ph.D. Archaeological Linguistics", size: 14)
                    HandNote(text: "Stanford University  ·  Dissertation: \"Parallel Symbol Systems in Pre-Contact Civilizations\"", size: 12, color: Color.inkSepia.opacity(0.65))
                }
            }
            .padding(.bottom, 14)

            SectionRule()

            HandTitle(text: "The Discovery", size: 17, color: .inkBlue)
                .padding(.bottom, 6)

            HandBody(text: "In the summer of 2024, Dr. Mandu was serving as scientific advisor aboard the R/V Peregrine when sonar anomalies led the crew to a previously uncharted volcanic island in the Mid-Atlantic Ridge.")

            Spacer(minLength: 14)

            HandBody(text: "On the island she found six tablets — each carved in the ancient script of a different civilization. Egyptian hieroglyphs. Norse runes. Sumerian cuneiform. Maya glyphs. Celtic ogham. Ancient Chinese oracle script. Teaching stones, she called them. Each one holding five inscriptions in its own script.")

            Spacer(minLength: 14)

            HandBody(text: "Beneath the six teaching tablets, half-buried in volcanic ash, she found a seventh stone. Partially carved. Six spaces left empty — one for each of the scripts above it.")

            Spacer(minLength: 10)

            HandNote(text: "\"Someone started this and stopped. Or left it unfinished on purpose. The empty spaces are not damage — the edges are too clean. They were meant to be filled.\"", color: Color.inkBlue.opacity(0.8))

            Spacer(minLength: 8)

            HandNote(text: "— Dr. Sandra Mandu, field notes, July 2024", size: 12, color: Color.inkSepia.opacity(0.55))

            Spacer(minLength: 14)

            HandNote(text: "Dr. Mandu's hypothesis: solve each civilization's teaching tablets to identify which symbol belongs in that civilization's empty space on the partial stone.", color: Color.inkRed.opacity(0.75))

            Spacer(minLength: 18)
            SectionRule()

            HandTitle(text: "Breaking the Egyptian Code", size: 17, color: .inkBlue)
                .padding(.bottom, 6)

            HandBody(text: "After three days with the Egyptian partial tablets, I finally understood the rule. It is, at its heart, a Latin square — a grid in which every symbol appears exactly once in every row and exactly once in every column.")

            Spacer(minLength: 10)

            HandBody(text: "No symbol may repeat on any horizontal line. No symbol may repeat on any vertical line. The fixed stones give you the anchor points. Everything else follows by elimination.")

            Spacer(minLength: 10)

            // Example image
            Image("latin_square")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.inkSepia.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)

            Spacer(minLength: 10)

            HandNote(text: "The 3×3 example above shows the simplest form. The larger tablets use 4 or 5 symbols — same rule, more deduction required.", color: Color.inkSepia.opacity(0.7))

            Spacer(minLength: 10)

            HandNote(text: "Variants complicate it further: one tablet forbids identical symbols from touching on any side; another hides invisible chamber boundaries that must also be respected. But the Latin square is always the foundation.", color: Color.inkRed.opacity(0.75))
        }
    }
}

// MARK: - Egypt Puzzle Page

private struct EgyptPuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "𓂀", civ: "Egypt", puzzle: "Latin Square",
                             tagline: "Order · Balance · The Sacred Grid")
            SectionRule()
            HandBody(text: "The Egyptian tablets are arranged as Latin squares. Every row must contain each symbol exactly once. Every column must contain each symbol exactly once. The ancient scribes considered any repetition a form of spiritual disorder.")
            Spacer(minLength: 10)
            HandBody(text: "Begin from the fixed stones — the pre-carved anchors. From each anchor, ask what is still possible in its row and in its column. Every certainty eliminates options. Follow the chain until no empty cell remains.")
            SectionRule()
            HandTitle(text: "The Five Variants", size: 16, color: .inkBlue)
                .padding(.bottom, 4)
            variantRow(num: "I",   rule: "Row & Column Rule",     desc: "The pure Latin square. One of each, everywhere.")
            variantRow(num: "II",  rule: "No Adjacent Rule",      desc: "No symbol may touch a copy of itself on any side.")
            variantRow(num: "III", rule: "Hidden Chambers Rule",  desc: "Invisible regions each demand one of every symbol.")
            variantRow(num: "IV",  rule: "Five Forces",           desc: "Five symbols, five directions — larger grid.")
            variantRow(num: "V",   rule: "Pure Deduction",        desc: "Only five anchors. All else follows from reason alone.")
            SectionRule()
            HandNote(text: "Solve all five tablets to decode Egypt's row on the Tablet of Mandu.", color: Color.inkBlue.opacity(0.8))
        }
    }

    private func variantRow(num: String, rule: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(handFont(13, bold: true))
                .foregroundStyle(Color.inkBlue.opacity(0.7))
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule)
                    .font(handFont(13, bold: true))
                    .foregroundStyle(Color.inkSepia)
                Text(desc)
                    .font(handFont(12))
                    .foregroundStyle(Color.inkSepia.opacity(0.65))
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Sumerian Puzzle Page

private struct MesopotamiaPuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "𒀭", civ: "Sumerian", puzzle: "Cipher",
                             tagline: "Decryption · Substitution · The Hidden Key")
            SectionRule()
            HandBody(text: "The Sumerian cuneiform tablets speak in code. Where the Egyptian tablets arrange symbols in balanced grids, these tablets conceal their message through substitution — each position in the inscription encodes a symbol according to a hidden key.")
            Spacer(minLength: 10)
            HandBody(text: "The key itself must be discovered from within the tablet. Certain positions are pre-revealed as anchor points. From these knowns, the cipher's logic can be reconstructed, one symbol at a time.")
            SectionRule()
            HandTitle(text: "Dr. Mandu's Notes", size: 16, color: .inkBlue)
                .padding(.bottom, 4)
            HandNote(text: "Cuneiform is the world's oldest writing system — wedge shapes pressed into wet clay with a reed stylus. The Sumerians were the first people to write down laws, contracts, and stories. It follows that their puzzle would be about encoding and decoding messages.", color: Color.inkSepia.opacity(0.75))
            Spacer(minLength: 8)
            HandNote(text: "This is not about arrangement. It is about substitution and revelation. Find the pattern in what is already shown. The cipher will cascade open from there.", color: Color.inkRed.opacity(0.75))
            SectionRule()
            HandNote(text: "Coming in the next phase of the Mandu Expedition.", color: Color.inkSepia.opacity(0.45))
        }
    }
}

// MARK: - Celtic Puzzle Page

private struct GreecePuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "ᚉ", civ: "Celtic / Druidic", puzzle: "Ogham Inscription",
                             tagline: "Grove · Stone · The Druidic Alphabet")
            SectionRule()
            HandBody(text: "The Celtic Ogham stones bear inscriptions carved as notches along a central stem line. Each mark is a letter named for a sacred tree. The Druids encoded their knowledge in wood and stone, in groves that no Roman army dared enter.")
            Spacer(minLength: 10)
            HandBody(text: "The tablet's puzzle emerges from the structure of the inscription itself. The Ogham alphabet is ordered — each letter has a fixed position in a sequence that the Druids memorized before they were allowed to carve. Find the order and the blanks fill themselves.")
            SectionRule()
            HandTitle(text: "Dr. Mandu's Notes", size: 16, color: .inkBlue)
                .padding(.bottom, 4)
            HandNote(text: "Ogham was carved vertically — bottom to top, along the edge of a standing stone. The Druids spent twenty years memorizing sacred knowledge before writing a single letter. Their puzzle is not about cleverness. It is about patience and sequence.", color: Color.inkSepia.opacity(0.75))
            Spacer(minLength: 8)
            HandNote(text: "Every tree has its place in the grove. Every letter has its place in the alphabet. Trust the order.", color: Color.inkRed.opacity(0.75))
            SectionRule()
            HandNote(text: "Coming in the next phase of the Mandu Expedition.", color: Color.inkSepia.opacity(0.45))
        }
    }
}

// MARK: - China Puzzle Page

private struct ChinaPuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "木", civ: "Ancient China", puzzle: "Wooden Box",
                             tagline: "Shape · Rotation · The Craftsman's Tray")
            SectionRule()
            HandBody(text: "The Chinese oracle bone tablets present a spatial puzzle. Carved wooden pieces of different shapes must be fitted into a rectangular tray — each piece rotated and placed so that every cell is covered, with no gaps and no overlaps.")
            Spacer(minLength: 10)
            HandBody(text: "The craftsmen of the Han dynasty used puzzle trays to train apprentices in spatial reasoning. The pieces look simple. The arrangement is anything but. A piece that fits in one corner may block the only path to completion.")
            SectionRule()
            HandTitle(text: "Dr. Mandu's Notes", size: 16, color: .inkBlue)
                .padding(.bottom, 4)
            HandNote(text: "Oracle bone script was used for divination — questions scratched into bone or shell, heated until they cracked, and the cracks were read as answers. The ancient Chinese were asking the universe for answers. This tablet asks us the same thing, differently.", color: Color.inkSepia.opacity(0.75))
            Spacer(minLength: 8)
            HandNote(text: "Rotation is everything. The same piece that seems wrong at one angle becomes the only piece that fits when turned. Do not force it. Turn it.", color: Color.inkRed.opacity(0.75))
            SectionRule()
            HandNote(text: "Coming in the next phase of the Mandu Expedition.", color: Color.inkSepia.opacity(0.45))
        }
    }
}

// MARK: - Norse Puzzle Page

private struct NorsePuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "ᛚ", civ: "Norse", puzzle: "Pathfinding",
                             tagline: "Navigation · Survival · The Runic Way")
            SectionRule()
            HandBody(text: "The Norse runestone tablets are pathfinding puzzles. You must trace a route through the stone that visits each symbol in the correct sequence, never crossing your own path, navigating from start to finish by instinct and memory.")
            Spacer(minLength: 10)
            HandBody(text: "The Vikings navigated by stars, ocean currents, bird flight, and the color of the sea. They did not need maps. They read the world itself. This tablet tests the same skill — reading a hidden path through a field of runes.")
            SectionRule()
            HandTitle(text: "Dr. Mandu's Notes", size: 16, color: .inkBlue)
                .padding(.bottom, 4)
            HandNote(text: "Each rune is more than a letter — it is a force. Isa is ice. Kenaz is fire. Uruz is the wild ox. Placing them in sequence is not spelling — it is invocation. The path through the runestone is a ritual as much as a puzzle.", color: Color.inkSepia.opacity(0.75))
            Spacer(minLength: 8)
            HandNote(text: "Do not try to plan the entire route at once. Follow the force of the runes. The path will make itself known.", color: Color.inkRed.opacity(0.75))
            SectionRule()
            HandNote(text: "Coming in the next phase of the Mandu Expedition.", color: Color.inkSepia.opacity(0.45))
        }
    }
}

// MARK: - Maya Puzzle Page

private struct MesoamericanPuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "ᛚ", civ: "Maya", puzzle: "Pattern & Rhythm",
                             tagline: "Cycle · Calendar · The Interlocking Wheels")
            SectionRule()
            HandBody(text: "The Maya calendar tablets are pattern puzzles. Symbols repeat in precise, interlocking cycles — the 260-day Tzolk'in turning inside the 365-day Haab', producing a great cycle that repeats once every 52 years. Identify the rhythm and you can fill every gap.")
            Spacer(minLength: 10)
            HandBody(text: "The ancients left deliberate blanks in the sequence. They are tests. Once you feel the pulse of the cycle — once the rhythm becomes intuitive — the missing symbols announce themselves.")
            SectionRule()
            HandTitle(text: "Dr. Mandu's Notes", size: 16, color: .inkBlue)
                .padding(.bottom, 4)
            HandNote(text: "The Maya Calendar is one of the most accurate astronomical systems ever devised, developed without telescopes, without calculators, from centuries of patient sky-watching. Their puzzle encodes that same patience: you must feel the beat before you can complete the measure.", color: Color.inkSepia.opacity(0.75))
            Spacer(minLength: 8)
            HandNote(text: "This is not logic in the Greek sense, and not balance in the Egyptian sense. It is rhythm. Trust what you feel repeating.", color: Color.inkRed.opacity(0.75))
            SectionRule()
            HandNote(text: "Coming in the next phase of the Mandu Expedition.", color: Color.inkSepia.opacity(0.45))
        }
    }
}

// MARK: - Shared puzzle-page header helper

private func puzzlePageHeader(emblem: String, civ: String, puzzle: String, tagline: String) -> some View {
    VStack(alignment: .center, spacing: 6) {
        Text(emblem)
            .font(.system(size: 38))
            .foregroundStyle(Color.inkBlue.opacity(0.65))
            .frame(maxWidth: .infinity, alignment: .center)
        HandTitle(text: civ, size: 26, color: .inkBlue)
            .frame(maxWidth: .infinity, alignment: .center)
        Text("Puzzle Type:  \(puzzle)")
            .font(handFont(15, bold: true))
            .foregroundStyle(Color.inkRed.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .center)
        Text(tagline)
            .font(handFont(12))
            .foregroundStyle(Color.inkSepia.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .center)
    }
    .padding(.bottom, 4)
}

// MARK: - Game Design Notes (DEBUG only)

#if DEBUG
private struct GameDesignNotesContent: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                HandTitle(text: "⚙ Game Design Notes")
                HandNote(text: "Debug reference only — not visible in release builds.", color: Color.inkRed.opacity(0.7))
                SectionRule()

                // MARK: Civilization Roles — Mastermind Pieces
                HandTitle(text: "Mastermind Pieces — Tree of Life Roles")
                HandNote(text: "Each civ's mastermind piece is either the key it received from the previous civilization, or — for Egypt — the key it kept for itself.", color: Color.inkSepia.opacity(0.65))
                designRow(symbol: "𒀭", civ: "Sumerian", role: "BOUGH",  note: "AN — the heavenward reach. Produced by Sumerian, kept as its own piece.")
                designRow(symbol: "ᛚ",  civ: "Maya",     role: "WATER",  note: "Laguz — the water rune received from Norse. What Norse passed down, Maya carries.")
                designRow(symbol: "𓊹", civ: "Egypt",    role: "TRUNK",  note: "Neter — the divine flag Egypt kept. It gave the Djed to Norse; kept the Neter.")
                designRow(symbol: "𓊽", civ: "Norse",    role: "ROOTS",  note: "Djed pillar received from Egypt. What Egypt passed down, Norse carries into the ground.")
                designRow(symbol: "ᚅ",  civ: "Celtic",   role: "FROND",  note: "Nion/Ash — produced by Celtic, kept as its own piece.")
                designRow(symbol: "☰",  civ: "China",    role: "SOLAR",  note: "Qian trigram — unique to China. Not received from anyone; the final light.")
                designRow(symbol: "ᚱ",  civ: "— (Ramer)", role: "DECOY", note: "Already on the tablet when found. Belongs to no civilization. Always left over.")

                SectionRule()

                // MARK: Mandu Tablet — Correct Order
                HandTitle(text: "Mandu Tablet — Correct Left-to-Right Order")
                HandNote(text: "𒀭  ·  ᛚ  ·  𓊹  ·  𓊽  ·  ᚅ  ·  ☰", color: Color.inkBlue)
                HandNote(text: "Sumerian · Maya · Egypt · Norse · Celtic · China", color: Color.inkSepia.opacity(0.75))
                HandNote(text: "BOUGH · WATER · TRUNK · ROOTS · FROND · SOLAR", color: Color.inkSepia.opacity(0.55))
                HandNote(text: "Logic: bough reaches up, water rises through it, trunk holds, roots drink, frond spreads, solar reveals all.", color: Color.inkSepia.opacity(0.45))

                SectionRule()

                // MARK: Gate Keys — Relay Chain
                HandTitle(text: "Gate Keys — Relay Chain")
                HandNote(text: "Egypt is the only civilization that produces TWO keys — one for each of its two Tier 2 successors.", color: Color.inkSepia.opacity(0.65))
                keyChainRow(from: "Egypt", produces: "𓊽 Djed",  to: "Norse L1",        note: "The pillar — what endures when everything falls")
                keyChainRow(from: "Egypt", produces: "𓊹 Neter", to: "Sumerian L1",     note: "The divine flag — before the name of every god")
                keyChainRow(from: "Norse",    produces: "ᛚ Laguz", to: "Maya L1",        note: "Water rune — flow toward the lowest place")
                keyChainRow(from: "Sumerian", produces: "𒀭 AN",   to: "Celtic L1",      note: "Heaven — the divine anchor above the flood")
                keyChainRow(from: "Maya",     produces: "ᚅ Nion",  to: "China L1 slot 1", note: "The ash — water was always reaching upward")
                keyChainRow(from: "Celtic",   produces: "ᚅ Nion",  to: "China L1 slot 2", note: "Same symbol, second source — the player's aha moment")
                keyChainRow(from: "China",    produces: "—",        to: "Mandu Tablet",   note: "Final civ — no key produced, unlocks the mastermind")

                SectionRule()

                // MARK: Key Chain → Mastermind Piece Traceability
                HandTitle(text: "Key Chain → Mastermind Piece")
                HandNote(text: "What you receive, you contribute.", color: Color.inkSepia.opacity(0.65))
                traceRow(civ: "Egypt",    received: "nothing",   produced: "𓊽 𓊹", mastermind: "𓊹", logic: "Gave Djed to Norse, kept Neter")
                traceRow(civ: "Norse",    received: "𓊽",        produced: "ᛚ",    mastermind: "𓊽", logic: "Carries what Egypt passed down")
                traceRow(civ: "Sumerian", received: "𓊹",        produced: "𒀭",   mastermind: "𒀭", logic: "Keeps what it produces for Celtic")
                traceRow(civ: "Maya",     received: "ᛚ",         produced: "ᚅ",    mastermind: "ᛚ",  logic: "Carries what Norse passed down")
                traceRow(civ: "Celtic",   received: "𒀭",        produced: "ᚅ",    mastermind: "ᚅ",  logic: "Keeps what it produces for China")
                traceRow(civ: "China",    received: "ᚅ ᚅ",       produced: "—",    mastermind: "☰",  logic: "Unique — the final light, not passed on")

                SectionRule()

                // MARK: Choice Picker — Decoy Sets
                HandTitle(text: "Choice Picker — Decoy Sets")
                HandNote(text: "Six candidates shown when player taps the '?' in a Level 1 key gate. Correct answer marked ✓.", color: Color.inkSepia.opacity(0.55))
                decoyRow(puzzle: "Norse L1",          correct: "𓊽", choices: "𓊽 · 𓅱 · 𓆑 · 𓇳 · 𓈖 · 𓊪")
                decoyRow(puzzle: "Sumerian L1",       correct: "𓊹", choices: "𓊽 · 𓏏 · 𓂀 · 𓇌 · 𓊹 · 𓃭")
                decoyRow(puzzle: "Maya L1",           correct: "ᛚ",  choices: "ᛚ · ᚠ · ᚢ · ᛟ · ᛏ · ᚾ")
                decoyRow(puzzle: "Celtic L1",         correct: "𒀭", choices: "𒀭 · 𒀯 · 𒆷 · 𒄑 · 𒐈 · 𒀰")
                decoyRow(puzzle: "China L1 slot 1",   correct: "ᚅ",  choices: "ᚅ · ᚁ · ᚂ · ᚃ · ᚄ · ᛚ")
                decoyRow(puzzle: "China L1 slot 2",   correct: "ᚅ",  choices: "ᚅ · 𒀭 · 𓊽 · ᛚ · 𓇳 · 𒆷")

                SectionRule()

                // MARK: Tier Progression
                HandTitle(text: "Tier Progression")
                tierRow(tier: "Tier 1", civs: "Egypt",           note: "Unlocked at start")
                tierRow(tier: "Tier 2", civs: "Norse + Sumerian", note: "Unlocked after Egypt Level 5 complete")
                tierRow(tier: "Tier 3", civs: "Maya + Celtic",    note: "Unlocked after Norse AND Sumerian Level 5 complete")
                tierRow(tier: "Tier 4", civs: "China",            note: "Unlocked after Maya OR Celtic Level 5 complete")
                HandNote(text: "Mandu Tablet — accessible at any time, solvable only after all six civilizations complete.", color: Color.inkSepia.opacity(0.55))

                SectionRule()

                // MARK: Acrostic Words
                HandTitle(text: "Acrostic Words — Puzzle Inscription Hints")
                HandNote(text: "Each civilization's 5 levels spell out its tree-part role. The first letter of the first inscription in each level is underlined.", color: Color.inkSepia.opacity(0.65))
                acrosticRow(civ: "Egypt",    word: "TRUNK",  letters: "T · R · U · N · K")
                acrosticRow(civ: "Norse",    word: "ROOTS",  letters: "R · O · O · T · S")
                acrosticRow(civ: "Sumerian", word: "BOUGH",  letters: "B · O · U · G · H")
                acrosticRow(civ: "Maya",     word: "WATER",  letters: "W · A · T · E · R")
                acrosticRow(civ: "Celtic",   word: "FROND",  letters: "F · R · O · N · D")
                acrosticRow(civ: "Chinese",  word: "SOLAR",  letters: "S · O · L · A · R")

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Row Builders

    private func designRow(symbol: String, civ: String, role: String, note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(symbol)
                .font(handFont(18))
                .foregroundStyle(Color.inkBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(civ) — \(role)")
                    .font(handFont(13, bold: true))
                    .foregroundStyle(Color.inkSepia)
                Text(note)
                    .font(handFont(11))
                    .foregroundStyle(Color.inkSepia.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func keyChainRow(from: String, produces: String, to: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(from)
                    .font(handFont(12, bold: true))
                    .foregroundStyle(Color.inkSepia)
                Text("produces")
                    .font(handFont(11))
                    .foregroundStyle(Color.inkSepia.opacity(0.45))
                Text(produces)
                    .font(handFont(14, bold: true))
                    .foregroundStyle(Color.inkBlue)
                Text("→")
                    .font(handFont(12))
                    .foregroundStyle(Color.inkSepia.opacity(0.4))
                Text(to)
                    .font(handFont(12))
                    .foregroundStyle(Color.inkSepia)
            }
            Text(note)
                .font(handFont(11))
                .foregroundStyle(Color.inkSepia.opacity(0.50))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func traceRow(civ: String, received: String, produced: String, mastermind: String, logic: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(mastermind)
                .font(handFont(18))
                .foregroundStyle(Color.inkBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(civ)
                        .font(handFont(12, bold: true))
                        .foregroundStyle(Color.inkSepia)
                    Text("received \(received)  ·  produced \(produced)")
                        .font(handFont(11))
                        .foregroundStyle(Color.inkSepia.opacity(0.55))
                }
                Text(logic)
                    .font(handFont(11))
                    .foregroundStyle(Color.inkSepia.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func decoyRow(puzzle: String, correct: String, choices: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(puzzle)
                .font(handFont(12, bold: true))
                .foregroundStyle(Color.inkSepia)
            HStack(spacing: 4) {
                Text("✓ \(correct)")
                    .font(handFont(13))
                    .foregroundStyle(Color.inkRed.opacity(0.8))
                Text("from:")
                    .font(handFont(11))
                    .foregroundStyle(Color.inkSepia.opacity(0.40))
                Text(choices)
                    .font(handFont(13))
                    .foregroundStyle(Color.inkBlue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tierRow(tier: String, civs: String, note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(tier)
                .font(handFont(12, bold: true))
                .foregroundStyle(Color.inkRed.opacity(0.75))
                .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(civs)
                    .font(handFont(12, bold: true))
                    .foregroundStyle(Color.inkSepia)
                Text(note)
                    .font(handFont(11))
                    .foregroundStyle(Color.inkSepia.opacity(0.50))
            }
        }
    }

    private func acrosticRow(civ: String, word: String, letters: String) -> some View {
        HStack(spacing: 8) {
            Text(civ)
                .font(handFont(12, bold: true))
                .foregroundStyle(Color.inkSepia)
                .frame(width: 64, alignment: .leading)
            Text(word)
                .font(handFont(12, bold: true))
                .foregroundStyle(Color.inkBlue)
                .frame(width: 44, alignment: .leading)
            Text(letters)
                .font(handFont(12))
                .foregroundStyle(Color.inkSepia.opacity(0.60))
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    JournalView()
        .environmentObject({
            let gs = GameState()
            gs.unlockedJournalEntries = [1, 2]
            gs.discoveredGlyphs = [.eye, .owl, .water, .lion]
            gs.decodedMessages = [1: Level.level1.decodedMessage, 2: Level.level2.decodedMessage]
            return gs
        }())
}
