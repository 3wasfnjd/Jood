-- All distances are studs. Geometry is baked into Joud-Hara.rbxlx.
return {
    Title = "جود — مجنونة الحارة",
    RoundSeconds = 600,
    ResetDelay = 9,
    FuseCount = 3,
    MaxCatches = 3,
    MaxActivePlayers = 6,
    WalkSpeed = 14,
    SprintSpeed = 23,
    StaminaDrain = 19,
    StaminaRecovery = 14,
    SightRange = 78,
    HearingRange = 33,
    PatrolSpeed = 9,
    ChaseSpeed = 18,
    CatchDistance = 3.6,
    HideSeconds = 22,
    InitialGrace = 16,
    RespawnGrace = 8,
    Spawn = Vector3.new(0, 4, 136),
    JoudSpawn = Vector3.new(0, 3.2, 53),
    SafeCenter = Vector3.new(0, 0, 136),
    SafeHalf = Vector3.new(19, 18, 17),
    ExitCenter = Vector3.new(0, 0, -168),
    ExitHalf = Vector3.new(10, 18, 10),

    -- الحبل: يظهر في مكان عشوائي، اللي ياخذه يربط جود مؤقتاً
    RopeFirstDelay = 20, -- أول حبل بعد بداية الجولة
    RopeRespawn = 25, -- بعد ما يُستخدم الحبل أو يضيع
    RopeRange = 14, -- لازم تكون قريب من جود
    RopeSeconds = 8, -- مدة الربط
    RageSeconds = 6, -- بعد ما تتحرر تكون معصبة
    RageSpeedBonus = 3,

    -- الحلاوة: تعطي طاقة ركض
    SweetCount = 8,
    SweetStamina = 35,
}
