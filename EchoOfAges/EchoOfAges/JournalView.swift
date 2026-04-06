// JournalView.swift
// EchoOfAges
//
// The Field Diary — displayed as a physical book with flippable pages.
// Swipe left/right to turn pages. All text uses a handwritten font.

import SwiftUI

// MARK: - Diary page type

private enum DiaryPage: Equatable {
    case frontPage
    case drMandu             // Dr. Elena Mandu biography + Egyptian Latin Square
    case mapPage
    case tabletStory
    case tabletGrid
    case civilizations
    // One puzzle-type page per civilization (in expedition order)
    case egyptPuzzle         // Egyptian  — Latin Square
    case mesopotamiaPuzzle   // Mesopotamia — Cipher
    case greecePuzzle        // Greece — Logic Grid
    case chinaPuzzle         // China — Spatial Assembly (Tangram)
    case norsePuzzle         // Norse — Pathfinding
    case mesoamericanPuzzle  // Mesoamerican — Pattern / Rhythm
    case codexGlyph(Glyph)
    case greekAlphabet
    case chronicle(Int)         // level id
    case fieldNotes             // current puzzle's clues
    case rosettaStone
    case champollionMethod
    case howToPlay
    case howToSolve
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
            .frontPage, .drMandu, .mapPage, .tabletStory, .tabletGrid, .civilizations,
            .howToPlay,
            .egyptPuzzle, .mesopotamiaPuzzle, .greecePuzzle,
            .chinaPuzzle, .norsePuzzle, .mesoamericanPuzzle
        ]
        // Codex: one page per known glyph
        for glyph in gameState.codexGlyphs { list.append(.codexGlyph(glyph)) }
        list.append(.greekAlphabet)
        // Chronicle: one page per decoded level
        for levelId in gameState.decodedMessages.keys.sorted() { list.append(.chronicle(levelId)) }
        // Field notes for current puzzle
        list.append(.fieldNotes)
        // Reference pages
        list.append(.rosettaStone)
        list.append(.champollionMethod)
        list.append(.howToSolve)
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
                        BookPage(pageType: pages[index], pageNumber: index + 1, totalPages: pages.count)
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
            if let spotId = gameState.spotlightJournalId {
                gameState.spotlightJournalId = nil
                // Jump to the chronicle page for this level
                if let idx = pages.firstIndex(of: .chronicle(spotId)) {
                    currentPageIndex = idx
                }
            } else {
                // Default: open at the front page
                currentPageIndex = 0
            }
        }
    }

    private var diaryTopBar: some View {
        HStack {
            Button(action: { gameState.closeJournal() }) {
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
        case .chronicle(let id):   ChronicleContent(levelId: id)
        case .fieldNotes:          FieldNotesContent()
        case .rosettaStone:        RosettaStoneContent()
        case .champollionMethod:   ChampollionContent()
        case .howToPlay:           HowToPlayContent()
        case .howToSolve:          HowToSolveContent()
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
    var body: some View {
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
            Text("Property of the Expedition Archaeologist")
                .font(handFont(13))
                .foregroundStyle(Color.inkSepia.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
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
            HandBody(text: "Equidistant between South America and Africa. Whatever trade route brought these objects here, we don't know it.")
            Spacer(minLength: 8)
            HandNote(text: "Coordinates withheld pending further excavation. The team agreed.", color: Color.inkRed.opacity(0.7))
        }
    }
}

private struct TabletStoryContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "The Tablet of Mandu")
            HandBody(text: "Found it on the third day. Half-buried under two feet of black volcanic sand. The stone is unlike anything in our geological surveys — dense, dark, almost glassy.")
            SectionRule()
            HandBody(text: "30 symbols. I counted them four times. They come from six different writing systems — Egyptian hieroglyphs, Norse runes, Sumerian cuneiform, Maya glyphs, Celtic ogham, ancient Chinese oracle script.")
            Spacer(minLength: 8)
            HandBody(text: "No civilization could have traveled to meet all the others. The carbon dating came back — the tablet predates every script that appears on it.")
            Spacer(minLength: 10)
            HandNote(text: "It should not exist.", color: Color.inkRed)
            SectionRule()
            HandBody(text: "Around the main tablet: six smaller tablets, each in a single script. Teaching tools, I think. As if someone wanted whoever found these to be able to decode the main inscription.")
            Spacer(minLength: 8)
            HandBody(text: "The team named it the Tablet of Mandu. Nobody knows what Mandu means. We found no language it comes from.")
            Spacer(minLength: 8)
            HandNote(text: "Not yet.", color: Color.inkSepia.opacity(0.6))
        }
    }
}

private struct TabletGridContent: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "The Tablet — Symbol Grid")
            HandNote(text: "6 rows, 5 symbols each. Symbols light up as each civilization's partial tablets are deciphered.", color: Color.inkSepia.opacity(0.7))
            SectionRule()

            let slots = TabletSlot.all
            let decoded = gameState.decodedTabletSlots

            VStack(spacing: 4) {
                ForEach(Civilization.all) { civ in
                    let row = slots.filter { $0.civilization == civ.id }
                    let isCivDone = gameState.completedCivilizations.contains(civ.id)

                    HStack(spacing: 4) {
                        Text(civ.emblem)
                            .font(.system(size: 14))
                            .foregroundStyle(isCivDone ? civ.accentColor : Color.inkSepia.opacity(0.25))
                            .frame(width: 22)

                        ForEach(row) { slot in
                            let isDecoded = decoded.contains(slot.id)
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isDecoded ? civ.accentColor.opacity(0.15) : Color.paperDark.opacity(0.7))
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(isDecoded ? civ.accentColor.opacity(0.6) : Color.inkSepia.opacity(0.18), lineWidth: isDecoded ? 1 : 0.5))
                                if isDecoded {
                                    VStack(spacing: 1) {
                                        Text(slot.character).font(.system(size: 17)).foregroundStyle(civ.accentColor)
                                        Text(slot.decoded).font(handFont(9)).foregroundStyle(Color.inkSepia.opacity(0.7)).lineLimit(1)
                                    }
                                } else {
                                    Text("?").font(handFont(16, bold: true)).foregroundStyle(Color.inkSepia.opacity(0.18))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                        }
                    }
                }
            }

            SectionRule()
            let count = gameState.decodedTabletSlots.count
            HandNote(text: "\(count) of 30 symbols decoded.", color: count == 30 ? Color.inkBlue : Color.inkSepia.opacity(0.6))

            SectionRule()
            if gameState.allSixCivsComplete {
                HandNote(text: "All six civilizations deciphered. The stone holds its secrets forever.", color: Color.inkBlue.opacity(0.9))
            } else {
                HandNote(
                    text: "The stone is always open. Place the symbols you have learned — but they fall away each time you close it. They hold only when all six civilizations are complete.",
                    color: Color.inkSepia.opacity(0.70)
                )
            }
            Spacer(minLength: 8)
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

            ForEach(Array(level.inscriptions.enumerated()), id: \.offset) { i, note in
                HStack(alignment: .top, spacing: 10) {
                    Text("—")
                        .font(handFont(15))
                        .foregroundStyle(Color.inkRed.opacity(0.7))
                    HandBody(text: note)
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
            HandBody(text: "Six ancient civilizations left behind partial tablets near the Tablet of Mandu — teaching tools, as if someone wanted whoever found them to be able to decode the main inscription.")

            SectionRule()

            // Step 1
            HStack(alignment: .top, spacing: 10) {
                Text("I").font(handFont(15, bold: true)).foregroundStyle(Color.inkRed).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "Start with Egypt", size: 15, color: .inkBlue)
                    HandBody(text: "Egypt's partial tablets use hieroglyphs arranged in a grid. No symbol repeats in any row or column. Fill the grid using logic — no guessing required.", size: 14)
                }
            }

            SectionRule()

            // Step 2
            HStack(alignment: .top, spacing: 10) {
                Text("II").font(handFont(15, bold: true)).foregroundStyle(Color.inkRed).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "Norse & Sumerian Unlock Together", size: 15, color: .inkBlue)
                    HandBody(text: "Complete all five Egyptian tablets and two new civilizations open: Norse runes (a pathfinding puzzle — trace the correct route through the runestone) and Sumerian cuneiform (a substitution cipher — decode a message using symbols you uncover).", size: 14)
                    HandNote(text: "You can play Norse and Sumerian in any order, or switch between them.", size: 12, color: Color.inkSepia.opacity(0.6))
                }
            }

            SectionRule()

            // Step 3
            HStack(alignment: .top, spacing: 10) {
                Text("III").font(handFont(15, bold: true)).foregroundStyle(Color.inkRed).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "Maya & Celtic Follow", size: 15, color: .inkBlue)
                    HandBody(text: "Finish both Norse and Sumerian and two more civilizations appear: Maya glyphs and Celtic ogham. Complete either one to unlock the sixth and final civilization.", size: 14)
                }
            }

            SectionRule()

            // Step 4
            HStack(alignment: .top, spacing: 10) {
                Text("IV").font(handFont(15, bold: true)).foregroundStyle(Color.inkRed).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "Chinese Oracle Script — The Final Gate", size: 15, color: .inkBlue)
                    HandBody(text: "Complete Maya or Celtic and the last civilization unlocks: ancient Chinese oracle bone script. Master all five of its tablets to complete your sixth and final row on the Tablet of Mandu.", size: 14)
                }
            }

            SectionRule()

            // The Mandu Tablet
            HStack(alignment: .top, spacing: 10) {
                Text("𓇳").font(.system(size: 15)).foregroundStyle(Color(red: 0.60, green: 0.42, blue: 0.10)).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    HandTitle(text: "The Tablet of Mandu — Always Open", size: 15, color: .inkBlue)
                    HandBody(text: "The final puzzle is accessible from this diary at any time. As you complete each civilization, their symbols become available in the palette. Place them on the stone where they belong.", size: 14)
                    Spacer(minLength: 4)
                    HandNote(text: "But the stone does not hold your work. Every time you close it, the placed symbols fall away — they are only held in place when all six civilizations are fully deciphered.", size: 13, color: Color.inkRed.opacity(0.75))
                    Spacer(minLength: 4)
                    HandNote(text: "When all six are complete: return to the stone, place all thirty symbols, and the inscription will reveal itself.", size: 13, color: Color.inkSepia.opacity(0.65))
                }
            }
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
            HandTitle(text: "Dr. Elena Mandu", size: 26, color: .inkBlue)
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

                Text("Dr. Elena Mandu, 2024")
                    .font(handFont(11))
                    .foregroundStyle(Color.inkSepia.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 16)
            }

            SectionRule()

            // Biography
            HandBody(text: "Dr. Elena Mandu is one of the world's foremost authorities on ancient writing systems and cross-cultural linguistics. With her signature thick-framed glasses and an unnerving ability to read a room — or a ruin — she has led excavations on four continents.")

            Spacer(minLength: 14)

            HandBody(text: "Born in São Paulo, Brazil, Elena displayed an obsession with pattern and language from an early age. She taught herself Ancient Greek at fourteen using library books and stubbornness in equal measure.")

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

            HandBody(text: "In the summer of 2024, Dr. Mandu was serving as a scientific advisor aboard the R/V Peregrine when sonar anomalies led the crew to a previously uncharted volcanic island in the Mid-Atlantic Ridge.")

            Spacer(minLength: 14)

            HandBody(text: "It was Elena who first recognized the obsidian slab for what it was. She cleared the ash from its surface with her own hands, and when the first symbols emerged, she reportedly said nothing for four minutes.")

            Spacer(minLength: 14)

            HandNote(text: "\"I have spent my whole career looking for proof that the ancient world was more connected than we think. I was not prepared to actually find it.\"", color: Color.inkBlue.opacity(0.8))

            Spacer(minLength: 14)

            HandNote(text: "— Dr. Elena Mandu, interview with Nature, September 2024", size: 12, color: Color.inkSepia.opacity(0.55))

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

// MARK: - Mesopotamia Puzzle Page

private struct MesopotamiaPuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "𒀭", civ: "Mesopotamia", puzzle: "Cipher",
                             tagline: "Decryption · Substitution · The Hidden Key")
            SectionRule()
            HandBody(text: "The Mesopotamian cuneiform tablets speak in code. Where the Egyptian tablets arrange symbols in balanced grids, these tablets conceal their message through substitution — each position in the inscription encodes a symbol according to a hidden key.")
            Spacer(minLength: 10)
            HandBody(text: "The key itself must be discovered from within the tablet. Certain positions are pre-revealed as anchor points. From these knowns, the cipher's logic can be reconstructed, one symbol at a time.")
            SectionRule()
            HandTitle(text: "Dr. Mandu's Notes", size: 16, color: .inkBlue)
                .padding(.bottom, 4)
            HandNote(text: "Cuneiform is the world's oldest writing system — wedge shapes pressed into wet clay with a reed stylus. The Mesopotamians were the first people to write down laws, contracts, and stories. It follows that their puzzle would be about encoding and decoding messages.", color: Color.inkSepia.opacity(0.75))
            Spacer(minLength: 8)
            HandNote(text: "This is not about arrangement. It is about substitution and revelation. Find the pattern in what is already shown. The cipher will cascade open from there.", color: Color.inkRed.opacity(0.75))
            SectionRule()
            HandNote(text: "Coming in the next phase of the Mandu Expedition.", color: Color.inkSepia.opacity(0.45))
        }
    }
}

// MARK: - Greece Puzzle Page

private struct GreecePuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "Ω", civ: "Greece", puzzle: "Logic Grid",
                             tagline: "Reason · Deduction · The Philosophical Method")
            SectionRule()
            HandBody(text: "The Greek tablets do not show you the symbols directly. Instead, they present a series of logical clues — statements that rule out possibilities, one by one. You must deduce which symbol belongs in which position using only the power of reason.")
            Spacer(minLength: 10)
            HandBody(text: "No guessing. No trial and error. The Greek method demands that every placement be proven from what is already known. Aristotle called it the syllogism. The ancients carved it in stone.")
            SectionRule()
            HandTitle(text: "Dr. Mandu's Notes", size: 16, color: .inkBlue)
                .padding(.bottom, 4)
            HandNote(text: "Greek philosophy gave us formal logic — the idea that truth can be derived step by step from premises. This tablet embodies that tradition. Each clue is a premise. Each deduction is a conclusion. The final arrangement is the proof.", color: Color.inkSepia.opacity(0.75))
            Spacer(minLength: 8)
            HandNote(text: "Unlike the Egyptian grid, there is no spatial pattern to fall back on. You must reason your way through entirely.", color: Color.inkRed.opacity(0.75))
            SectionRule()
            HandNote(text: "Coming in the next phase of the Mandu Expedition.", color: Color.inkSepia.opacity(0.45))
        }
    }
}

// MARK: - China Puzzle Page

private struct ChinaPuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "甲", civ: "China", puzzle: "Spatial Assembly",
                             tagline: "Shape · Fit · The Tangram Tradition")
            SectionRule()
            HandBody(text: "The Chinese oracle bone tablets present a spatial puzzle. Individual glyph-shaped tiles must be assembled into the correct final configuration — each piece fitting exactly against the next, no gaps, no overlaps, nothing wasted.")
            Spacer(minLength: 10)
            HandBody(text: "The Tangram is China's ancient geometric puzzle: seven pieces, one perfect shape. This tablet uses the same principle. You are given the pieces. You must find the arrangement. The whole reveals itself from the parts.")
            SectionRule()
            HandTitle(text: "Dr. Mandu's Notes", size: 16, color: .inkBlue)
                .padding(.bottom, 4)
            HandNote(text: "Oracle bone script was used for divination — questions scratched into bone or shell, heated until they cracked, and the cracks were read as answers. The ancient Chinese were asking the universe for answers. This tablet asks us the same thing, differently.", color: Color.inkSepia.opacity(0.75))
            Spacer(minLength: 8)
            HandNote(text: "Spatial reasoning. Pattern visualization. See the final shape in your mind before you begin placing pieces.", color: Color.inkRed.opacity(0.75))
            SectionRule()
            HandNote(text: "Coming in the next phase of the Mandu Expedition.", color: Color.inkSepia.opacity(0.45))
        }
    }
}

// MARK: - Norse Puzzle Page

private struct NorsePuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "ᚱ", civ: "Norse", puzzle: "Pathfinding",
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

// MARK: - Mesoamerican Puzzle Page

private struct MesoamericanPuzzleContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            puzzlePageHeader(emblem: "𝋠", civ: "Mesoamerica", puzzle: "Pattern & Rhythm",
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
