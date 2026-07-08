//
//  CardQueries.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

enum CardQueries { }

// MARK: - Card Lookup

extension CardQueries {

    static let cardByID = """
    SELECT *
    FROM cards
    WHERE card_id = ?
    LIMIT 1;
    """

    static let cardByPrinting = """
    SELECT *
    FROM cards
    WHERE
        name = ?
        AND set_code = ?
        AND collector_number = ?
    ORDER BY
        CASE COALESCE(lang, 'en')
            WHEN 'en' THEN 0
            ELSE 1
        END
    LIMIT 1;
    """

    static let languagesByPrinting = """
    SELECT DISTINCT COALESCE(lang, 'en')
    FROM cards
    WHERE
        name = ? COLLATE NOCASE
        AND set_code = ? COLLATE NOCASE
        AND collector_number = ?
    ORDER BY
        CASE COALESCE(lang, 'en')
            WHEN 'en' THEN 0
            ELSE 1
        END,
        lang COLLATE NOCASE;
    """

    static let allPrintings = """
    SELECT *
    FROM cards
    WHERE name = ?
    COLLATE NOCASE
        AND COALESCE(lang, 'en') = 'en'
    ORDER BY
        set_name,
        collector_number;
    """

    static func cards(ids count: Int) -> String {

        precondition(count > 0)

        let placeholders = Array(
            repeating: "?",
            count: count
        ).joined(separator: ",")

        return """
        SELECT *
        FROM cards
        WHERE card_id IN (\(placeholders));
        """
    }
}

//
// MARK: - Search
//

extension CardQueries {

    static let searchBase = """
    SELECT *
    FROM cards
    """

    static let searchOrder = """
    ORDER BY
        name COLLATE NOCASE,
        set_name,
        collector_number;
    """
}

//
// MARK: - Sets
//

extension CardQueries {

    static let allSets = """
    SELECT DISTINCT set_code
    FROM cards
    WHERE set_code IS NOT NULL
      AND set_code != ''
    ORDER BY set_code COLLATE NOCASE;
    """

    static let allSetInfo = """
    SELECT
        set_code,
        COALESCE(set_name, '') AS set_name,
        COUNT(*) AS card_count
    FROM cards
    WHERE set_code IS NOT NULL
      AND set_code != ''
    GROUP BY set_code, set_name
    ORDER BY set_name COLLATE NOCASE;
    """

    static let searchSetInfo = """
    SELECT
        set_code,
        COALESCE(set_name, '') AS set_name,
        COUNT(*) AS card_count
    FROM cards
    WHERE
        set_code LIKE ?
        OR set_name LIKE ?
    GROUP BY set_code, set_name
    ORDER BY set_name COLLATE NOCASE;
    """
}

//
// MARK: - Artists
//

extension CardQueries {

    static let allArtists = """
    SELECT DISTINCT artist
    FROM cards
    WHERE artist IS NOT NULL
      AND artist != ''
    ORDER BY artist COLLATE NOCASE;
    """

    static let searchArtists = """
    SELECT DISTINCT artist
    FROM cards
    WHERE artist IS NOT NULL
      AND artist != ''
      AND artist LIKE ?
    ORDER BY artist COLLATE NOCASE;
    """

    static let cardsByArtist = """
    SELECT *
    FROM cards
    WHERE artist = ?
    COLLATE NOCASE
    ORDER BY name COLLATE NOCASE, set_code, collector_number;
    """
}

//
// MARK: - Statistics
//

extension CardQueries {

    static let statistics = """
    SELECT
        COUNT(*) AS total_cards,
        COUNT(DISTINCT name) AS unique_card_names,
        COUNT(DISTINCT NULLIF(set_code, '')) AS total_sets,
        COUNT(DISTINCT NULLIF(artist, '')) AS total_artists,
        SUM(
            CASE
                WHEN price_usd IS NOT NULL AND price_usd != ''
                THEN 1
                ELSE 0
            END
        ) AS cards_with_usd_price
    FROM cards;
    """

    static let featurePrintCount = """
    SELECT COUNT(*)
    FROM feature_prints;
    """
}
//
// MARK: - Import
//

extension CardQueries {

    static let insertCard = """
    INSERT OR REPLACE INTO cards
    (
        card_id,
        name,
        mana_cost,
        cmc,
        colors,
        color_identity,
        artist,
        type_line,
        oracle_text,
        power,
        toughness,
        rarity,
        set_code,
        set_name,
        collector_number,
        image_uri_normal,
        image_uri_art_crop,
        price_usd,
        price_usd_foil,
        scryfall_uri,
        layout,
        set_type,
        illustration_id,
        legalities,
        digital,
        card_faces_json,
        released_at,
        lang
    )
    VALUES
    (
        ?,?,?,?,?,?,
        ?,?,?,?,?,?,
        ?,?,?,?,?,?,
        ?,?,?,?,?,?,
        ?,?,?,?
    );
    """

    static let deleteCards =
        "DELETE FROM cards;"
}

//
// MARK: - Feature Prints
//

extension CardQueries {

    static let featurePrint = """
    SELECT *
    FROM feature_prints
    WHERE card_id = ?
    LIMIT 1;
    """

    static let insertFeaturePrint = """
    INSERT OR REPLACE INTO feature_prints
    (
        card_id,
        feature_print,
        feature_print_cropped,
        feature_print_full
    )
    VALUES (?, ?, ?, ?);
    """

    static let deleteFeaturePrints =
        "DELETE FROM feature_prints;"
}

//
// MARK: - Schema
//

extension CardQueries {

    static let createCardsTable = """
    CREATE TABLE IF NOT EXISTS cards (
        card_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mana_cost TEXT,
        cmc REAL,

        colors TEXT,
        color_identity TEXT,
        artist TEXT,

        type_line TEXT,
        oracle_text TEXT,
        power TEXT,
        toughness TEXT,

        rarity TEXT,
        set_code TEXT,
        set_name TEXT,
        collector_number TEXT,

        image_uri_normal TEXT,
        image_uri_art_crop TEXT,

        price_usd TEXT,
        price_usd_foil TEXT,

        scryfall_uri TEXT,

        layout TEXT,
        set_type TEXT,

        illustration_id TEXT,
        legalities TEXT,
        digital TEXT,
        card_faces_json TEXT,
        released_at TEXT,
        lang TEXT
    );
    """

    static let createFeaturePrintTable = """
    CREATE TABLE IF NOT EXISTS feature_prints
    (
        card_id TEXT PRIMARY KEY,
        feature_print BLOB,
        feature_print_cropped BLOB,
        feature_print_full BLOB
    );
    """

    static let indexes = [

        """
        CREATE INDEX IF NOT EXISTS idx_cards_name
        ON cards(name COLLATE NOCASE);
        """,

        """
        CREATE INDEX IF NOT EXISTS idx_cards_set
        ON cards(set_code);
        """,

        """
        CREATE INDEX IF NOT EXISTS idx_cards_rarity
        ON cards(rarity);
        """,

        """
        CREATE INDEX IF NOT EXISTS idx_cards_illustration
        ON cards(illustration_id);
        """
    ]
}

extension CardQueries {

    static let cardsByIllustrationID = """
    SELECT *
    FROM cards
    WHERE illustration_id = ?
        AND COALESCE(lang, 'en') = 'en'
    ORDER BY set_name, collector_number;
    """
}

extension CardQueries {

    static let allCards = """
    SELECT *
    FROM cards
    WHERE COALESCE(lang, 'en') = 'en'
    ORDER BY name COLLATE NOCASE;
    """
}
