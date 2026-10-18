-- إعدادات لعبة "جود" — كل الأرقام القابلة للضبط هنا

local Config = {}

-- الخريطة: شبكة أزقة، والبيوت في البلوكات بينها
Config.Alleys = { -80, -40, 0, 40, 80 }
Config.BlockCenters = { -60, -20, 20, 60 }
Config.MapHalf = 88
Config.AlleyWidth = 12
Config.MapSeed = 1447

-- أعمدة الإنارة (عند تقاطعات الأزقة الخارجية)
Config.LampPositions = {
	Vector3.new(-80, 0, -80),
	Vector3.new(80, 0, -80),
	Vector3.new(-80, 0, 80),
	Vector3.new(80, 0, 80),
	Vector3.new(0, 0, -80),
	Vector3.new(0, 0, 80),
}
-- هذي الأعمدة تحتاج لاعبَين يسحبون مفتاحين بنفس الوقت
Config.DualLamps = { [5] = true, [6] = true }
Config.DualWindow = 2.5 -- ثواني: الفرق المسموح بين سحب المفتاحين

Config.LampSafeRadius = 18 -- نصف قطر المنطقة الآمنة تحت العمود
Config.FuseHold = 4
Config.RepairHold = 5
Config.LeverHold = 1.5
Config.LanternHold = 5
Config.ReviveHold = 3

-- الجولة
Config.Intermission = 10
Config.Grace = 20 -- مهلة قبل ظهور جود
Config.BleedOut = 30 -- ثواني قبل ما يخرج اللاعب الطايح
Config.FinaleTime = 60
Config.FinaleMinLamps = 5 -- الفانوس يتقدم فقط إذا هذا العدد من الأعمدة شغال
Config.EndScreenTime = 12

-- جود
Config.JoodSpeedBase = 11
Config.JoodSpeedPerLamp = 0.8
Config.JoodSpeedFinale = 17
Config.JoodCatchDistance = 4
Config.JoodCatchCooldown = 4
Config.JoodSenseRange = 140
Config.BreakIntervalBase = 75
Config.BreakIntervalPerLamp = 6
Config.BreakIntervalMin = 35
Config.BreakIntervalFinale = 18
Config.BreakWarning = 5

-- اللاعب والكشاف
Config.PlayerWalkSpeed = 16
Config.FlashRange = 32
Config.FlashAngle = 22 -- درجات
Config.FlashSlow = 0.45 -- جود تمشي بهذي النسبة من سرعتها تحت الكشاف
Config.BatteryDrain = 4 -- بالثانية
Config.BatteryRechargeLight = 12
Config.BatteryRechargeDark = 1

return Config
