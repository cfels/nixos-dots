import QtQuick

Item {
	id: fonts
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property string cyrillicFont: ruFont.status === FontLoader.Ready ? ruFont.name : fonts.fontFamily
	readonly property string japaneseFont: jpFont.status === FontLoader.Ready ? jpFont.name : fonts.fontFamily
	readonly property string koreanFont: krFont.status === FontLoader.Ready ? krFont.name : fonts.fontFamily

	function lyricFont(text): string {
		var value = "" + text

		if (/[\uAC00-\uD7A3\u1100-\u11FF\u3130-\u318F]/.test(value))
			return fonts.koreanFont
		if (/[\u3040-\u30FF\u31F0-\u31FF\u4E00-\u9FFF\uF900-\uFAFF]/.test(value))
			return fonts.japaneseFont
		if (/[\u0400-\u04FF\u0500-\u052F]/.test(value))
			return fonts.cyrillicFont

		return fonts.fontFamily
	}

	function lyricWeight(text, active): int {
		if (fonts.lyricFont(text) !== fonts.fontFamily)
			return Font.ExtraBold

		return active ? Font.DemiBold : Font.Normal
	}

	FontLoader {
		id: momo
		source: "../fonts/momotrust.ttf"
	}

	FontLoader {
		id: ruFont
		source: "../fonts/NotoSans-ExtraBold-RU.ttf"
	}

	FontLoader {
		id: jpFont
		source: "../fonts/NotoSansJP-ExtraBold.ttf"
	}

	FontLoader {
		id: krFont
		source: "../fonts/NotoSansKR-ExtraBold.ttf"
	}
}
