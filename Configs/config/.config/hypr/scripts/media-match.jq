def norm: ascii_downcase | gsub("[^\\p{L}\\p{N}]+"; " ") | gsub("^ +| +$"; "");
def artists: ascii_downcase
	| [splits("\\s+(?:feat\\.?|ft\\.?|featuring)\\s+|\\s*[,;&、，]\\s*")]
	| map((capture("^.*[（(]\\s*cv\\s*[:：]\\s*(?<performer>[^）)]+)[）)]\\s*$").performer // .) | norm)
	| map(select(length > 0));
def adiff: if . < 0 then -. else . end;

def matched_tracks($title; $artist; $album; $dur):
	($title | norm) as $wantT
	| ($artist | artists) as $wantA
	| ($album | norm) as $wantAlbum
	| (($dur // 0) | if . < 0 then 0 else . end) as $wantD
	| [ .[]
		| . as $c
		| (($c.title // "") | norm) as $ct
		| (($c.artist // "") | artists) as $ca
		| select($wantT != "" and $ct == $wantT)
		| select(($wantA | length) > 0 and ($wantA - $ca | length) == 0)
		| select($wantD <= 0 or ($c.duration // 0) <= 0 or (((($c.duration // 0) - $wantD) | adiff) <= 3))
		| $c + {
			score: ((if $ca == $wantA then 2 else 1 end)
				+ (if $wantAlbum != "" and (($c.album // "") | norm) == $wantAlbum then 2 else 0 end)
				+ (if ($wantD > 0 and ($c.duration // 0) > 0)
					then ((($c.duration // 0) - $wantD) | adiff) as $dd
						| 4 - $dd
					else 0 end))
		}
	]
	| sort_by(if ((.synced // .syncedLyrics // "") | length) > 0 then 0 else 1 end, -.score);
