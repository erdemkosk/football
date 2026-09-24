extends RefCounted
## Authored hierarchy for fictional clubs, on the existing low overall scale.
## Spain has two giants; England/Italy wider leading groups; France/Germany a
## dominant club; Portugal/Netherlands a small leading pack. These are game
## balance values, not official ratings or boosts applied during a match.
const BONUSES := {
	"c00":6,"c01":9,"c02":2,"c04":7,"c05":5,
	"c36":14,"c37":14,"c48":6,"c50":8,
	"c38":8,"c39":10,"c54":6,
	"c40":14,"c41":9,"c60":10,"c61":9,
	"c42":4,"c43":14,"c66":9,
	"c44":12,"c45":5,"c72":6,
	"c46":14,"c78":12,"c79":14,"c80":10,"c81":5,
	"c47":10,"c85":10,"c86":8,
	"tr00":9,"tr01":10,"tr02":7,"tr03":8
}
# Revision 3 strengthens the chasing groups and middle of the national leagues.
# Keep the V2 baseline so existing careers receive only the authored difference,
# including players who have since transferred or developed beyond their cap.
# General hierarchy reference: https://www.uefa.com/nationalassociations/uefarankings/
# These fictional identities are not one-to-one copies of real clubs.
const REGIONAL_ADJUSTMENTS := {
	"c39":1,"c54":3,
	"c41":3,"c60":3,"c61":4,"c62":6,"c63":3,"c64":7,
	"c42":3,"c66":3,"c67":6,"c68":4,"c69":2,"c70":3,"c71":2,
	"c45":1,"c72":3,"c73":3,"c74":3,"c75":2,"c76":2,"c77":2,
	"c78":3,"c79":4,"c80":3,"c81":3,"c82":4,"c83":2,"c84":2,
	"c85":3,"c86":4,"c87":3,"c89":2
}

static func club_bonus(id: String,revision: int=3) -> int:
	return int(BONUSES.get(id,0))+(int(REGIONAL_ADJUSTMENTS.get(id,0)) if revision>=3 else 0)

static func origin(p: Dictionary) -> Dictionary:
	if p.has("talent_club"):
		return {"club":str(p.talent_club),"slot":int(p.get("talent_slot",-1))}
	# Before origin metadata existed, the initial squads used contiguous,
	# immutable appearance IDs. Transfers, loans and shirt changes do not
	# change those IDs. Academy graduates must never inherit a senior boost.
	if p.get("academy_owner","")!="" or p.get("promoted",false): return {"club":"","slot":-1}
	var serial: int=int(p.appearance_id)
	if serial>=0 and serial<2208: return {"club":"c%02d" % (serial/24),"slot":serial%24}
	if serial>=2208 and serial<2640: return {"club":"tr%02d" % ((serial-2208)/24),"slot":(serial-2208)%24}
	return {"club":"","slot":-1}

static func bonus(p: Dictionary,revision: int=3) -> int:
	var seed_club := origin(p)
	var amount := club_bonus(seed_club.club,revision)
	if seed_club.slot<0: return 0
	# Good clubs have a strong core and useful substitutes, not 24 identical
	# stars. Existing standout players at smaller clubs remain possible.
	return maxi(0,amount-(12 if seed_club.slot>=18 else 8 if seed_club.slot>=11 else 0))

static func ceiling(p: Dictionary) -> int:
	var seed_club := origin(p)
	var amount := club_bonus(seed_club.club)
	var featured: int=[6,9,10][posmod(int(p.appearance_id)/24,3)]
	return 92 if amount>=12 and seed_club.slot==featured else 88
