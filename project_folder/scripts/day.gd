extends WorldEnvironment

func _ready() -> void:
    # ১. একটি নতুন Environment রিসোর্স তৈরি করুন (যদি ইতিমধ্যে না থাকে)
    var env = Environment.new()
    
    # ============================
    # ২. SKY (আকাশ) সেটআপ - ভায়োলেন্ট/ডার্ক থিম
    # ============================
    env.background_mode = Environment.BG_SKY
    
    var sky = Sky.new()
    var sky_mat = ProceduralSkyMaterial.new()
    
    # রংগুলো ডার্ক ও রক্তিম রাখা হয়েছে
    sky_mat.sky_top_color = Color(0.1, 0.1, 0.1)          # গাঢ় কালো
    sky_mat.sky_horizon_color = Color(0.5, 0.0, 0.0)     # রক্তিম লাল
    sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.02) # প্রায় কালো
    sky_mat.sky_curve = 0.15
    sky_mat.sun_angle_max = 15.0
    sky_mat.sun_color = Color(1.0, 0.3, 0.1)             # ফ্যাকাসে লাল/কমলা আলো
    
    sky.sky_material = sky_mat
    env.sky = sky
    
    # ============================
    # ৩. AMBIENT LIGHT (পরিবেশের আলো)
    # ============================
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_color = Color(0.17, 0.17, 0.19)    # গাঢ় নীলাভ ধূসর
    env.ambient_light_energy = 0.35                      # আলো অনেক কম (অন্ধকারাচ্ছন্ন)
    
    # ============================
    # ৪. FOG (কুয়াশা)
    # ============================
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_DEPTH
    env.fog_light_color = Color(0.15, 0.05, 0.05)        # কালচে লাল কুয়াশা
    env.fog_density = 0.025
    env.fog_height = -1.0                                # নিচের দিকে বেশি কুয়াশা (ঐচ্ছিক)
    
    # ============================
    # ৫. TONEMAP (রঙের কনট্রাস্ট - সিনেমাটিক ইফেক্ট)
    # ============================
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_white = 1.0
    env.tonemap_exposure = 0.8                           # এক্সপোজার একটু কমিয়ে অন্ধকার করা
    
    # ============================
    # ৬. শেষে এই নোডের এনভায়রনমেন্ট হিসেবে সেট করুন
    # ============================
    self.environment = env
    
    print("WorldEnvironment fully configured via script!")