// water_rule.wgsl - Native GPU-Resident JIT Water cellular automata & fluid loop.
//
// Input/Output variable is:
//   var water: vec4<f32>; // (x: Water, y: Lava, z: Acid, w: Crude Oil)
//
// Injected code here executes per-voxel. Use `water` to modify fluid simulation state.
//

let self_voxel = get_voxel(local_x, local_y, local_z);

// If the voxel is solid (SDF <= threshold), it cannot contain liquid
let solid_thresh = u.terrain_params3.z;
if (self_voxel.x <= solid_thresh) {
    water = vec4<f32>(0.0);
} else {
    var near_ceiling = false;
    var cold_ceiling = false;
    let gas_here = get_gas(local_x, local_y, local_z);
    let steam_here = gas_here.x;

    for (var dy = 1; dy <= 7; dy = dy + 1) {
        let ceiling_v = get_voxel(local_x, local_y + dy, local_z);
        if (ceiling_v.x <= solid_thresh) {
            near_ceiling = true;
            let ceil_mat = round(abs(ceiling_v.y));
            if (ceil_mat == 6.0) {
                cold_ceiling = true;
            }
            break;
        }
    }

    var w_below_v  = vec4<f32>(0.0);
    var w_below2_v = vec4<f32>(0.0);
    var w_above_v  = vec4<f32>(0.0);
    var w_left_v   = vec4<f32>(0.0);
    var w_right_v  = vec4<f32>(0.0);
    var w_back_v   = vec4<f32>(0.0);
    var w_front_v  = vec4<f32>(0.0);

    let self_idx = u32(local_x + local_y * 32 + local_z * 1024);
    if (local_x > 0 && local_x < 31 && local_y > 1 && local_y < 31 && local_z > 0 && local_z < 31) {
        w_below_v  = input_fields[self_idx - 32u];
        w_below2_v = input_fields[self_idx - 64u];
        w_above_v  = input_fields[self_idx + 32u];
        w_left_v   = input_fields[self_idx - 1u];
        w_right_v  = input_fields[self_idx + 1u];
        w_back_v   = input_fields[self_idx - 1024u];
        w_front_v  = input_fields[self_idx + 1024u];
    } else {
        w_below_v  = get_fluid(local_x, local_y - 1, local_z);
        w_below2_v = get_fluid(local_x, local_y - 2, local_z);
        w_above_v  = get_fluid(local_x, local_y + 1, local_z);
        w_left_v   = get_fluid(local_x - 1, local_y, local_z);
        w_right_v  = get_fluid(local_x + 1, local_y, local_z);
        w_back_v   = get_fluid(local_x, local_y, local_z - 1);
        w_front_v  = get_fluid(local_x, local_y, local_z + 1);
    }

    // Check voxel solidity for neighbors (SDF <= threshold is solid)
    let sol_below  = get_voxel(local_x, local_y - 1, local_z).x <= solid_thresh;
    let sol_below2 = get_voxel(local_x, local_y - 2, local_z).x <= solid_thresh;
    let sol_above  = get_voxel(local_x, local_y + 1, local_z).x <= solid_thresh;
    let sol_left  = get_voxel(local_x - 1, local_y, local_z).x <= solid_thresh;
    let sol_right = get_voxel(local_x + 1, local_y, local_z).x <= solid_thresh;
    let sol_back  = get_voxel(local_x, local_y, local_z - 1).x <= solid_thresh;
    let sol_front = get_voxel(local_x, local_y, local_z + 1).x <= solid_thresh;
    
    let flow_speed = u.misc_params.y;

    // --- 1. Water Flow Loop (gravity & spreading) ---
    var new_water = water.x;
    var w_flow_down_below = 0.0;
    if (!sol_below && !sol_below2) {
        w_flow_down_below = min(w_below_v.x, (1.0 - w_below2_v.x) * flow_speed);
    }
    var w_flow_down = 0.0;
    if (!sol_below) {
        w_flow_down = min(new_water, (1.0 - w_below_v.x + w_flow_down_below) * flow_speed);
    }
    var w_flow_from_above = 0.0;
    if (!sol_above) {
        var w_flow_self_below = 0.0;
        if (!sol_below) {
            w_flow_self_below = min(new_water, (1.0 - w_below_v.x) * flow_speed);
        }
        w_flow_from_above = min(w_above_v.x, (1.0 - new_water + w_flow_self_below) * flow_speed);
    }
    new_water = new_water - w_flow_down + w_flow_from_above;

    var w_flow_left  = 0.0;
    var w_flow_right = 0.0;
    var w_flow_back  = 0.0;
    var w_flow_front = 0.0;
    let w_spread_factor = min(0.20, 0.15 * flow_speed);
    if (!sol_left) {
        let sol_left_below = get_voxel(local_x - 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_left_below) {
            w_flow_left = min(water.x, (1.0 - w_left_v.x) * flow_speed * 0.85);
        } else if (!sol_below && sol_left_below) {
            w_flow_left = -min(w_left_v.x, (1.0 - water.x) * flow_speed * 0.85);
        } else if (sol_below) {
            w_flow_left = (water.x - w_left_v.x) * w_spread_factor;
        }
    }
    if (!sol_right) {
        let sol_right_below = get_voxel(local_x + 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_right_below) {
            w_flow_right = min(water.x, (1.0 - w_right_v.x) * flow_speed * 0.85);
        } else if (!sol_below && sol_right_below) {
            w_flow_right = -min(w_right_v.x, (1.0 - water.x) * flow_speed * 0.85);
        } else if (sol_below) {
            w_flow_right = (water.x - w_right_v.x) * w_spread_factor;
        }
    }
    if (!sol_back) {
        let sol_back_below = get_voxel(local_x, local_y - 1, local_z - 1).x <= solid_thresh;
        if (sol_below && !sol_back_below) {
            w_flow_back = min(water.x, (1.0 - w_back_v.x) * flow_speed * 0.85);
        } else if (!sol_below && sol_back_below) {
            w_flow_back = -min(w_back_v.x, (1.0 - water.x) * flow_speed * 0.85);
        } else if (sol_below) {
            w_flow_back = (water.x - w_back_v.x) * w_spread_factor;
        }
    }
    if (!sol_front) {
        let sol_front_below = get_voxel(local_x, local_y - 1, local_z + 1).x <= solid_thresh;
        if (sol_below && !sol_front_below) {
            w_flow_front = min(water.x, (1.0 - w_front_v.x) * flow_speed * 0.85);
        } else if (!sol_below && sol_front_below) {
            w_flow_front = -min(w_front_v.x, (1.0 - water.x) * flow_speed * 0.85);
        } else if (sol_below) {
            w_flow_front = (water.x - w_front_v.x) * w_spread_factor;
        }
    }
    new_water -= (w_flow_left + w_flow_right + w_flow_back + w_flow_front);
    if (new_water < 0.001 && !near_ceiling && sol_below) { new_water = 0.0; }

    // --- 2. Lava Flow Loop (highly viscous, slow gravity & spreading) ---
    var new_lava = water.y;
    let lava_flow_speed = flow_speed * select(0.08, 0.015, select(false, get_voxel(local_x, local_y - 1, local_z).y == 13.0, local_y > 0)); // slow viscous flow, unless sitting on hot lava rock
    var l_flow_down = 0.0;
    if (!sol_below) {
        l_flow_down = min(new_lava, (1.0 - w_below_v.y) * lava_flow_speed);
    }
    var l_flow_from_above = 0.0;
    if (!sol_above) {
        l_flow_from_above = min(w_above_v.y, (1.0 - new_lava) * lava_flow_speed);
    }
    new_lava = new_lava - l_flow_down + l_flow_from_above;

    var l_flow_left  = 0.0;
    var l_flow_right = 0.0;
    var l_flow_back  = 0.0;
    var l_flow_front = 0.0;
    let l_spread_factor = 0.06 * lava_flow_speed;
    if (!sol_left) {
        let sol_left_below = get_voxel(local_x - 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_left_below) {
            l_flow_left = min(new_lava, (1.0 - w_left_v.y) * lava_flow_speed * 0.85);
        } else if (!sol_below && sol_left_below) {
            l_flow_left = -min(w_left_v.y, (1.0 - new_lava) * lava_flow_speed * 0.85);
        } else if (sol_below) {
            l_flow_left = (water.y - w_left_v.y) * l_spread_factor;
        }
    }
    if (!sol_right) {
        let sol_right_below = get_voxel(local_x + 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_right_below) {
            l_flow_right = min(new_lava, (1.0 - w_right_v.y) * lava_flow_speed * 0.85);
        } else if (!sol_below && sol_right_below) {
            l_flow_right = -min(w_right_v.y, (1.0 - new_lava) * lava_flow_speed * 0.85);
        } else if (sol_below) {
            l_flow_right = (water.y - w_right_v.y) * l_spread_factor;
        }
    }
    if (!sol_back) {
        let sol_back_below = get_voxel(local_x, local_y - 1, local_z - 1).x <= solid_thresh;
        if (sol_below && !sol_back_below) {
            l_flow_back = min(new_lava, (1.0 - w_back_v.y) * lava_flow_speed * 0.85);
        } else if (!sol_below && sol_back_below) {
            l_flow_back = -min(w_back_v.y, (1.0 - new_lava) * lava_flow_speed * 0.85);
        } else if (sol_below) {
            l_flow_back = (water.y - w_back_v.y) * l_spread_factor;
        }
    }
    if (!sol_front) {
        let sol_front_below = get_voxel(local_x, local_y - 1, local_z + 1).x <= solid_thresh;
        if (sol_below && !sol_front_below) {
            l_flow_front = min(new_lava, (1.0 - w_front_v.y) * lava_flow_speed * 0.85);
        } else if (!sol_below && sol_front_below) {
            l_flow_front = -min(w_front_v.y, (1.0 - new_lava) * lava_flow_speed * 0.85);
        } else if (sol_below) {
            l_flow_front = (water.y - w_front_v.y) * l_spread_factor;
        }
    }
    new_lava -= (l_flow_left + l_flow_right + l_flow_back + l_flow_front);
    if (new_lava < 0.001) { new_lava = 0.0; }

    // --- 3. Acid Flow Loop (fast, highly corrosive) ---
    var new_acid = water.z;
    let acid_flow_speed = flow_speed * 0.65;
    var a_flow_down = 0.0;
    if (!sol_below) {
        a_flow_down = min(new_acid, (1.0 - w_below_v.z) * acid_flow_speed);
    }
    var a_flow_from_above = 0.0;
    if (!sol_above) {
        a_flow_from_above = min(w_above_v.z, (1.0 - new_acid) * acid_flow_speed);
    }
    new_acid = new_acid - a_flow_down + a_flow_from_above;

    var a_flow_left  = 0.0;
    var a_flow_right = 0.0;
    var a_flow_back  = 0.0;
    var a_flow_front = 0.0;
    let a_spread_factor = 0.15 * acid_flow_speed;
    if (!sol_left) {
        let sol_left_below = get_voxel(local_x - 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_left_below) {
            a_flow_left = min(new_acid, (1.0 - w_left_v.z) * acid_flow_speed * 0.85);
        } else if (!sol_below && sol_left_below) {
            a_flow_left = -min(w_left_v.z, (1.0 - new_acid) * acid_flow_speed * 0.85);
        } else if (sol_below) {
            a_flow_left = (water.z - w_left_v.z) * a_spread_factor;
        }
    }
    if (!sol_right) {
        let sol_right_below = get_voxel(local_x + 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_right_below) {
            a_flow_right = min(new_acid, (1.0 - w_right_v.z) * acid_flow_speed * 0.85);
        } else if (!sol_below && sol_right_below) {
            a_flow_right = -min(w_right_v.z, (1.0 - new_acid) * acid_flow_speed * 0.85);
        } else if (sol_below) {
            a_flow_right = (water.z - w_right_v.z) * a_spread_factor;
        }
    }
    if (!sol_back) {
        let sol_back_below = get_voxel(local_x, local_y - 1, local_z - 1).x <= solid_thresh;
        if (sol_below && !sol_back_below) {
            a_flow_back = min(new_acid, (1.0 - w_back_v.z) * acid_flow_speed * 0.85);
        } else if (!sol_below && sol_back_below) {
            a_flow_back = -min(w_back_v.z, (1.0 - new_acid) * acid_flow_speed * 0.85);
        } else if (sol_below) {
            a_flow_back = (water.z - w_back_v.z) * a_spread_factor;
        }
    }
    if (!sol_front) {
        let sol_front_below = get_voxel(local_x, local_y - 1, local_z + 1).x <= solid_thresh;
        if (sol_below && !sol_front_below) {
            a_flow_front = min(new_acid, (1.0 - w_front_v.z) * acid_flow_speed * 0.85);
        } else if (!sol_below && sol_front_below) {
            a_flow_front = -min(w_front_v.z, (1.0 - new_acid) * acid_flow_speed * 0.85);
        } else if (sol_below) {
            a_flow_front = (water.z - w_front_v.z) * a_spread_factor;
        }
    }
    new_acid -= (a_flow_left + a_flow_right + a_flow_back + a_flow_front);
    if (new_acid < 0.001) { new_acid = 0.0; }

    // --- 4. Crude Oil Flow Loop (viscous, highly flammable fuel) ---
    var new_oil = water.w;
    let oil_flow_speed = flow_speed * 0.35;
    var o_flow_down = 0.0;
    if (!sol_below) {
        o_flow_down = min(new_oil, (1.0 - w_below_v.w) * oil_flow_speed);
    }
    var o_flow_from_above = 0.0;
    if (!sol_above) {
        o_flow_from_above = min(w_above_v.w, (1.0 - new_oil) * oil_flow_speed);
    }
    new_oil = new_oil - o_flow_down + o_flow_from_above;

    var o_flow_left  = 0.0;
    var o_flow_right = 0.0;
    var o_flow_back  = 0.0;
    var o_flow_front = 0.0;
    let o_spread_factor = 0.10 * oil_flow_speed;
    if (!sol_left) {
        let sol_left_below = get_voxel(local_x - 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_left_below) {
            o_flow_left = min(new_oil, (1.0 - w_left_v.w) * oil_flow_speed * 0.85);
        } else if (!sol_below && sol_left_below) {
            o_flow_left = -min(w_left_v.w, (1.0 - new_oil) * oil_flow_speed * 0.85);
        } else if (sol_below) {
            o_flow_left = (water.w - w_left_v.w) * o_spread_factor;
        }
    }
    if (!sol_right) {
        let sol_right_below = get_voxel(local_x + 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_right_below) {
            o_flow_right = min(new_oil, (1.0 - w_right_v.w) * oil_flow_speed * 0.85);
        } else if (!sol_below && sol_right_below) {
            o_flow_right = -min(w_right_v.w, (1.0 - new_oil) * oil_flow_speed * 0.85);
        } else if (sol_below) {
            o_flow_right = (water.w - w_right_v.w) * o_spread_factor;
        }
    }
    if (!sol_back) {
        let sol_back_below = get_voxel(local_x, local_y - 1, local_z - 1).x <= solid_thresh;
        if (sol_below && !sol_back_below) {
            o_flow_back = min(new_oil, (1.0 - w_back_v.w) * oil_flow_speed * 0.85);
        } else if (!sol_below && sol_back_below) {
            o_flow_back = -min(w_back_v.w, (1.0 - new_oil) * oil_flow_speed * 0.85);
        } else if (sol_below) {
            o_flow_back = (water.w - w_back_v.w) * o_spread_factor;
        }
    }
    if (!sol_front) {
        let sol_front_below = get_voxel(local_x, local_y - 1, local_z + 1).x <= solid_thresh;
        if (sol_below && !sol_front_below) {
            o_flow_front = min(new_oil, (1.0 - w_front_v.w) * oil_flow_speed * 0.85);
        } else if (!sol_below && sol_front_below) {
            o_flow_front = -min(w_front_v.w, (1.0 - new_oil) * oil_flow_speed * 0.85);
        } else if (sol_below) {
            o_flow_front = (water.w - w_front_v.w) * o_spread_factor;
        }
    }
    new_oil -= (o_flow_left + o_flow_right + o_flow_back + o_flow_front);
    if (new_oil < 0.001) { new_oil = 0.0; }

    // --- Evaporation modulated by local heat ---
    var local_temp = 0.0;
    var total_weight = 0.0;
    let max_instances = u32(round(u.suns[0].params.y));
    for (var i = 0u; i < max_instances; i = i + 1u) {
        let inst = u.instances[i];
        let radius = inst.pos_scale.w;
        if (radius <= 0.0) { continue; }
        
        let dist = length(voxel_pos - inst.pos_scale.xyz);
        if (dist < radius) {
            let weight = 1.0 - (dist / radius);
            local_temp = local_temp + select(0.0, inst.interaction_fields.x, inst.interaction_fields.x > -999.0) * weight;
            total_weight = total_weight + weight;
        }
    }
    if (total_weight > 0.0) {
        local_temp = local_temp / total_weight;
    }

    let evap_mult = select(0.002, 1.0 + (local_temp - 20.0) * 0.18, local_temp > 20.0);
    let final_evap = u.misc_params.w * evap_mult * 3.5;

    // Water Evaporation (scaled 3.0x, disabled near ceilings, throttled by air dryness, and scaled down by 98% for falling water)
    let dryness = max(0.0, 1.0 - steam_here);
    let evap_scale = select(1.0, 0.02, !sol_below);
    let evaporated_water = select(min(new_water, 3.0 * final_evap * dt * 50.0 * dryness * evap_scale), 0.0, near_ceiling);
    new_water = new_water - evaporated_water;

    // Oil Evaporation (evaporates into Methane Gas)
    let evaporated_oil = min(new_oil, final_evap * dt * 15.0 * select(1.0, 5.0, local_temp > 60.0));
    new_oil = new_oil - evaporated_oil;

    // --- Liquid-Liquid Reactions ---
    // 1. Water vs Lava Steam explosion reaction
    if (new_water > 0.005 && new_lava > 0.005) {
        let react = min(new_water, new_lava) * 0.85;
        new_water = max(0.0, new_water - react);
        new_lava = max(0.0, new_lava - react);
    }
    // 2. Water vs Acid dilution
    if (new_water > 0.005 && new_acid > 0.005) {
        let react = min(new_water, new_acid) * 0.20;
        new_water = max(0.0, new_water - react);
        new_acid = max(0.0, new_acid - react);
    }

    // --- Combustion of Crude Oil ---
    // Oil combusts instantly if adjacent to Lava or if local temperature > 120 C
    let has_combustion_source = new_lava > 0.05 || w_below_v.y > 0.05 || w_above_v.y > 0.05 ||
                                 w_left_v.y > 0.05 || w_right_v.y > 0.05 ||
                                 w_back_v.y > 0.05 || w_front_v.y > 0.05 ||
                                 local_temp > 120.0;
    if (has_combustion_source && new_oil > 0.0) {
        // Oil burns steadily and generates smoke/heat
        let burned_oil = min(new_oil, 0.10 * dt);
        new_oil = new_oil - burned_oil;
    }

    // --- Acid contact with solid walls ---
    // Acid eats solid walls, generating fumes (excluding ceiling to allow condensation)
    let adjacent_to_solid = sol_left || sol_right || sol_back || sol_front || sol_below;
    if (adjacent_to_solid && new_acid > 0.0) {
        let consumed_acid = min(new_acid, 0.45);
        new_acid = new_acid - consumed_acid;
    }

    // --- Ceiling & Pressure Condensation (Vapor -> Liquid) ---
    var local_pressure = 0.0;
    {
        let max_inst = u32(round(u.suns[0].params.y));
        for (var i = 0u; i < max_inst; i = i + 1u) {
            let inst = u.instances[i];
            let radius = inst.pos_scale.w;
            if (radius <= 0.0) { continue; }
            let dist = length(voxel_pos - inst.pos_scale.xyz);
            if (dist < radius) {
                let weight = 1.0 - (dist / radius);
                local_pressure = local_pressure + inst.interaction_fields.z * weight;
            }
        }
    }

    let is_cold = cold_ceiling || (local_temp < 10.0);
    var total_condensed = 0.0;

    // 1. Regular Ceiling Condensation (lowered threshold to 0.02, with a moderate base speed so it pools and lingers)
    if (near_ceiling && steam_here >= 0.02) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let ceiling_condensation_rate = 0.10 * u.shadow_ao_quality.w * dt * rate_mult;
        total_condensed = total_condensed + min(steam_here, ceiling_condensation_rate);
    }

    // 1b. Acid Fog Ceiling Condensation
    var acid_condensed = 0.0;
    let acid_fog_here = gas_here.z;
    if (near_ceiling && acid_fog_here >= 0.02) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let acid_condensation_rate = 0.10 * u.shadow_ao_quality.w * dt * rate_mult;
        acid_condensed = min(acid_fog_here, acid_condensation_rate);
    }

    // 2. Shockwave / Pressure Condensation
    if (local_pressure > 5.0 && steam_here > 0.01) {
        let pressure_condensation_rate = 1.5 * dt * local_pressure;
        total_condensed = total_condensed + min(steam_here - total_condensed, pressure_condensation_rate);
    }

    // 3. Mid-air rain condensation (saturation-triggered downpour, with a high base speed to guarantee downpours)
    let rain_threshold = u.grid_dims.w;
    var rain_condensed = 0.0;
    if (steam_here > rain_threshold) {
        let rain_rate = 3.0 * (1.5 * u.shadow_ao_quality.w + 20.0) * dt * (steam_here - rain_threshold);
        rain_condensed = min(steam_here, rain_rate);
    }

    let combined_condensed = total_condensed + rain_condensed;
    if (combined_condensed > 0.0) {
        new_water = new_water + combined_condensed * 1.5; // boosted conversion factor for thick visible drops
    }
    if (acid_condensed > 0.0) {
        new_acid = new_acid + acid_condensed * 1.0;
    }

    water.x = clamp(new_water, 0.0, 1.0);
    water.y = clamp(new_lava, 0.0, 1.0);
    water.z = clamp(new_acid, 0.0, 1.0);
    water.w = clamp(new_oil, 0.0, 1.0);
}
