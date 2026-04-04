// JournalView.swift
// EchoOfAges
//
// The Field Diary — displayed as a physical book with flippable pages.
// Swipe left/right to turn pages. All text uses a handwritten font.

import SwiftUI

// MARK: - Diary page type

private enum DiaryPage: Equatable {
    case frontPage
    case mapPage
    case tabletStory
    case tabletGrid
    case civilizations
    case codexGlyph(Glyph)
    case greekAlphabet
    case chronicle(Int)         // level id
    case fieldNotes             // current puzzle's clues
    case rosettaStone
    case champollionMethod
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
        var list: [DiaryPage] = [.frontPage, .mapPage, .tabletStory, .tabletGrid, .civilizations]
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
        ZStack {
            Color.leatherBg.ignoresSafeArea()

            // Leather texture vignette
            RadialGradient(
                colors: [Color(red: 0.25, green: 0.16, blue: 0.06).opacity(0.0), Color(red: 0.05, green: 0.02, blue: 0.00).opacity(0.8)],
                center: .center, startRadius: 100, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                diaryTopBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Book pages
                TabView(selection: $currentPageIndex) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        BookPage(pageType: pages[index], pageNumber: index + 1, totalPages: pages.count)
                            .tag(index)
                            .environmentObject(gameState)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page navigation
                pageNav
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
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
                // Default: open to field notes
                if let idx = pages.firstIndex(of: .fieldNotes) {
                    currentPageIndex = idx
                }
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
        HStack(spacing: 20) {
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
            }

            Text("\(currentPageIndex + 1)  of  \(pages.count)")
                .font(handFont(15))
                .foregroundStyle(Color(red: 0.65, green: 0.50, blue: 0.28))

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
            }
        }
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
        case .frontPage:       FrontPageContent()
        case .mapPage:         MapPageContent()
        case .tabletStory:     TabletStoryContent()
        case .tabletGrid:      TabletGridContent()
        case .civilizations:   CivilizationsContent()
        case .codexGlyph(let g): CodexGlyphContent(glyph: g)
        case .greekAlphabet:   GreekAlphabetContent()
        case .chronicle(let id): ChronicleContent(levelId: id)
        case .fieldNotes:      FieldNotesContent()
        case .rosettaStone:    RosettaStoneContent()
        case .champollionMethod: ChampollionContent()
        case .howToSolve:      HowToSolveContent()
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
        }
    }
}

private struct CivilizationsContent: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HandTitle(text: "The Six Civilizations")
            HandBody(text: "Each partial tablet uses one script. Decipher all five puzzles from a civilization to read their row on the main tablet.")
            SectionRule()

            ForEach(Civilization.all) { civ in
                let isDone = gameState.completedCivilizations.contains(civ.id)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(civ.emblem).font(.system(size: 18)).foregroundStyle(isDone ? civ.accentColor : Color.inkSepia.opacity(0.35))
                        HandTitle(text: civ.name, size: 16, color: isDone ? Color.inkBlue : Color.inkSepia.opacity(0.5))
                        Spacer()
                        if isDone {
                            Text("✓ deciphered").font(handFont(12)).foregroundStyle(civ.accentColor)
                        } else if civ.isUnlocked {
                            Text("in progress").font(handFont(12)).foregroundStyle(Color.inkRed.opacity(0.7))
                        } else {
                            Text("locked").font(handFont(12)).foregroundStyle(Color.inkSepia.opacity(0.35))
                        }
                    }
                    HandNote(text: "\(civ.scriptName)  ·  \(civ.era)  ·  \(civ.region)", size: 12, color: Color.inkSepia.opacity(isDone ? 0.65 : 0.35))
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
