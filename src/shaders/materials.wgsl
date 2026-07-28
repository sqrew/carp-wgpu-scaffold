struct MaterialProperties {
    density: f32,
    strength: f32,       // crumbling/crushing limit
    erosion_rate: f32,   // base water erosion rate
    melt_temp: f32,      // melting point (for lava rules)
    melt_speed: f32,     // speed of melting
    acid_resist: f32,    // 0.0 = melts instantly, 1.0 = immune
}

fn get_material_properties(mat_id: f32) -> MaterialProperties {
    var props: MaterialProperties;
    
    // Default values (e.g. for grass/dirt/unrecognized)
    props.density = 1.0;
    props.strength = 14.0;
    props.erosion_rate = 0.25;
    props.melt_temp = 9999.0; // immune to melting
    props.melt_speed = 0.0;
    props.acid_resist = 0.3; // moderately vulnerable
    
    let m = i32(round(abs(mat_id)));
    
    if (m == 2) { // Natural Biome Green (Dirt/Grass)
        props.density = 1.0;
        props.strength = 14.0;
        props.erosion_rate = 0.25;
        props.melt_temp = 200.0; // organic burns easily
        props.melt_speed = 3.0;
        props.acid_resist = 0.1; // easily eaten
    } else if (m == 3) { // Stone Grey
        props.density = 2.0; // heavy
        props.strength = 24.0; // strong
        props.erosion_rate = 0.06; // hard to erode
        props.melt_temp = 1200.0; // melts at high temp
        props.melt_speed = 2.0;
        props.acid_resist = 0.7; // resistant
    } else if (m == 5) { // Sand Beige
        props.density = 1.2;
        props.strength = 4.0; // very weak structure
        props.erosion_rate = 0.8; // erodes very quickly
        props.melt_temp = 1400.0; // turns to glass at extremely high temp
        props.melt_speed = 1.0;
        props.acid_resist = 0.4;
    } else if (m == 6) { // Snow / Ice
        props.density = 0.5; // lightweight
        props.strength = 8.0;
        props.erosion_rate = 0.5; // melts/erodes in water
        props.melt_temp = 0.0; // melts at 0 degrees!
        props.melt_speed = 10.0; // melts extremely fast
        props.acid_resist = 0.8;
    } else if (m == 7 || m == 14) { // Volcanic Obsidian
        props.density = 2.5; // very dense
        props.strength = 36.0; // extremely strong
        props.erosion_rate = 0.005; // almost immune to water erosion
        props.melt_temp = 1600.0; // very high melting point
        props.melt_speed = 0.5;
        props.acid_resist = 1.0; // completely immune to acid!
    } else if (m == 8) { // Deep Cave Moss
        props.density = 0.8;
        props.strength = 6.0;
        props.erosion_rate = 0.40;
        props.melt_temp = 80.0; // organic burns easily
        props.melt_speed = 6.0;
        props.acid_resist = 0.1;
    } else if (m == 9) { // Amethyst Purple Crystal
        props.density = 2.2;
        props.strength = 28.0;
        props.erosion_rate = 0.02;
        props.melt_temp = 1400.0;
        props.melt_speed = 0.8;
        props.acid_resist = 0.9;
    } else if (m == 10) { // Clay Brown
        props.density = 1.5;
        props.strength = 12.0;
        props.erosion_rate = 0.15;
        props.melt_temp = 1000.0;
        props.melt_speed = 1.0;
        props.acid_resist = 0.5;
    } else if (m == 11) { // Glowing Neon Cyan
        props.density = 1.0;
        props.strength = 15.0;
        props.erosion_rate = 0.10;
        props.melt_temp = 800.0;
        props.melt_speed = 2.0;
        props.acid_resist = 0.5;
    } else if (m == 12) { // Shiny Gold / Brass
        props.density = 4.5; // extremely heavy payloads!
        props.strength = 30.0;
        props.erosion_rate = 0.01; // metal does not erode in water
        props.melt_temp = 900.0; // melts into lava
        props.melt_speed = 4.0;
        props.acid_resist = 0.6; // metals dissolve in acid
    } else if (m == 13) { // Pulsating Lava Crimson
        props.density = 2.0;
        props.strength = 10.0;
        props.erosion_rate = 0.10;
        props.melt_temp = -100.0; // always molten
        props.melt_speed = 0.0;
        props.acid_resist = 0.9;
    }
    
    return props;
}
