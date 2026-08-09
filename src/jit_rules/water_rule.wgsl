// water_rule.wgsl - Native GPU-Resident JIT Water cellular automata & fluid loop.
// Layout: water is vec4<f32>(Liquid_ID, Volume, Age, Sleep)

let self_voxel = get_voxel(local_x, local_y, local_z);

// If the voxel is solid (Material ID >= 0.9), it cannot contain liquid
if (self_voxel.y >= 0.9) {
    water = vec4<f32>(0.0);
} else {
    // Early-out Sleep state check
    let self_sleep = water.w;
    var should_simulate = true;
    if (self_sleep > 0.9) {
        let active_neighbor = 
            get_fluid(local_x - 1, local_y, local_z).w < 0.9 ||
            get_fluid(local_x + 1, local_y, local_z).w < 0.9 ||
            get_fluid(local_x, local_y - 1, local_z).w < 0.9 ||
            get_fluid(local_x, local_y + 1, local_z).w < 0.9 ||
            get_fluid(local_x, local_y, local_z - 1).w < 0.9 ||
            get_fluid(local_x, local_y, local_z + 1).w < 0.9;
        
        if (!active_neighbor) {
            should_simulate = false;
        }
    }

    if (should_simulate) {
        let baked_vals = get_baked_values(local_x, local_y, local_z);
        let slope = vec2<f32>(baked_vals.z, baked_vals.w) * 2.0 - 1.0;
        let slope_bias_x = -slope.x * 0.15;
        let slope_bias_z = -slope.y * 0.15;

        // Check voxel solidity for neighbors (Material ID >= 0.9 is solid)
        let sol_below  = get_voxel(local_x, local_y - 1, local_z).y >= 0.9;
        let sol_above  = get_voxel(local_x, local_y + 1, local_z).y >= 0.9;
        let sol_left   = get_voxel(local_x - 1, local_y, local_z).y >= 0.9;
        let sol_right  = get_voxel(local_x + 1, local_y, local_z).y >= 0.9;
        let sol_back   = get_voxel(local_x, local_y, local_z - 1).y >= 0.9;
        let sol_front  = get_voxel(local_x, local_y, local_z + 1).y >= 0.9;

        // Fetch neighbor liquids
        let w_below_v = get_fluid(local_x, local_y - 1, local_z);
        let w_above_v = get_fluid(local_x, local_y + 1, local_z);
        let w_left_v  = get_fluid(local_x - 1, local_y, local_z);
        let w_right_v = get_fluid(local_x + 1, local_y, local_z);
        let w_back_v  = get_fluid(local_x, local_y, local_z - 1);
        let w_front_v = get_fluid(local_x, local_y, local_z + 1);

        var self_id = round(water.x);
        var self_vol = water.y;
        var self_age = water.z;

        var next_id = self_id;
        var next_vol = self_vol;
        var next_age = self_age;

        // Resolve flow speed and weight properties for self
        var self_flow_speed = 0.0;
        var self_weight = 0.0;
        var self_evap_rate = 0.0;
        if (self_id == 1.0) { // Water
            self_flow_speed = 1.0;
            self_weight = 1.0;
            self_evap_rate = 0.02;
        } else if (self_id == 2.0) { // Lava
            self_flow_speed = 0.08;
            self_weight = 2.0;
            self_evap_rate = 0.0;
        } else if (self_id == 3.0) { // Acid
            self_flow_speed = 0.65;
            self_weight = 1.2;
            self_evap_rate = 0.01;
        } else if (self_id == 4.0) { // Oil
            self_flow_speed = 0.35;
            self_weight = 0.8;
            self_evap_rate = 0.015;
        }

        let global_flow_speed = u.misc_params.y * dt * 45.0;

        // --- 1. Downward Advection Flow ---
        if (self_id > 0.0 && self_vol > 0.005) {
            if (!sol_below) {
                let below_id = round(w_below_v.x);
                let below_vol = w_below_v.y;
                if (below_id == 0.0 || below_id == self_id) {
                    let flow_down = min(next_vol, (1.0 - below_vol) * global_flow_speed * self_flow_speed);
                    next_vol -= flow_down;
                }
            }
        } else {
            // We are empty, check if above is falling into us
            let above_id = round(w_above_v.x);
            if (above_id > 0.0 && w_above_v.y > 0.005 && !sol_above) {
                var above_flow_speed = 1.0;
                if (above_id == 2.0) { above_flow_speed = 0.08; }
                else if (above_id == 3.0) { above_flow_speed = 0.65; }
                else if (above_id == 4.0) { above_flow_speed = 0.35; }
                
                let flow_in = min(w_above_v.y, (1.0 - next_vol) * global_flow_speed * above_flow_speed);
                next_vol += flow_in;
                next_id = above_id;
                next_age = w_above_v.z;
            }
        }

        // --- 2. Displacement Swap ---
        // If the fluid above is heavier than us, swap places
        if (next_id > 0.0 && next_vol > 0.01) {
            let above_id = round(w_above_v.x);
            var above_weight = 0.0;
            if (above_id == 1.0) { above_weight = 1.0; }
            else if (above_id == 2.0) { above_weight = 2.0; }
            else if (above_id == 3.0) { above_weight = 1.2; }
            else if (above_id == 4.0) { above_weight = 0.8; }
            
            if (above_id > 0.0 && w_above_v.y > 0.01 && above_weight > self_weight) {
                next_id = above_id;
                next_vol = w_above_v.y;
                next_age = w_above_v.z;
            } else {
                // Swap with below if below is lighter
                let below_id = round(w_below_v.x);
                var below_weight = 0.0;
                if (below_id == 1.0) { below_weight = 1.0; }
                else if (below_id == 2.0) { below_weight = 2.0; }
                else if (below_id == 3.0) { below_weight = 1.2; }
                else if (below_id == 4.0) { below_weight = 0.8; }
                
                if (below_id > 0.0 && w_below_v.y > 0.01 && below_weight < self_weight) {
                    next_id = below_id;
                    next_vol = w_below_v.y;
                    next_age = w_below_v.z;
                }
            }
        }

        // --- 3. Lateral Spreading Flow ---
        if (next_id > 0.0 && next_vol > 0.005) {
            let spread_rate = 0.15 * global_flow_speed * self_flow_speed;
            
            // Spread Left
            if (!sol_left) {
                let left_id = round(w_left_v.x);
                let left_vol = w_left_v.y;
                if (left_id == 0.0 || left_id == next_id) {
                    let flow_lat = max(0.0, (next_vol - left_vol) * spread_rate + slope_bias_x * next_vol);
                    next_vol -= flow_lat;
                }
            }
            // Spread Right
            if (!sol_right) {
                let right_id = round(w_right_v.x);
                let right_vol = w_right_v.y;
                if (right_id == 0.0 || right_id == next_id) {
                    let flow_lat = max(0.0, (next_vol - right_vol) * spread_rate - slope_bias_x * next_vol);
                    next_vol -= flow_lat;
                }
            }
            // Spread Back
            if (!sol_back) {
                let back_id = round(w_back_v.x);
                let back_vol = w_back_v.y;
                if (back_id == 0.0 || back_id == next_id) {
                    let flow_lat = max(0.0, (next_vol - back_vol) * spread_rate + slope_bias_z * next_vol);
                    next_vol -= flow_lat;
                }
            }
            // Spread Front
            if (!sol_front) {
                let front_id = round(w_front_v.x);
                let front_vol = w_front_v.y;
                if (front_id == 0.0 || front_id == next_id) {
                    let flow_lat = max(0.0, (next_vol - front_vol) * spread_rate - slope_bias_z * next_vol);
                    next_vol -= flow_lat;
                }
            }
        } else {
            // We are empty, check if neighbors are spreading into us
            let spread_rate = 0.15 * global_flow_speed;
            
            var max_incoming = 0.0;
            var incoming_id = 0.0;
            var incoming_age = 0.0;
            
            // Left
            let left_id = round(w_left_v.x);
            if (left_id > 0.0 && w_left_v.y > max_incoming && !sol_left) {
                max_incoming = w_left_v.y;
                incoming_id = left_id;
                incoming_age = w_left_v.z;
            }
            // Right
            let right_id = round(w_right_v.x);
            if (right_id > 0.0 && w_right_v.y > max_incoming && !sol_right) {
                max_incoming = w_right_v.y;
                incoming_id = right_id;
                incoming_age = w_right_v.z;
            }
            // Back
            let back_id = round(w_back_v.x);
            if (back_id > 0.0 && w_back_v.y > max_incoming && !sol_back) {
                max_incoming = w_back_v.y;
                incoming_id = back_id;
                incoming_age = w_back_v.z;
            }
            // Front
            let front_id = round(w_front_v.x);
            if (front_id > 0.0 && w_front_v.y > max_incoming && !sol_front) {
                max_incoming = w_front_v.y;
                incoming_id = front_id;
                incoming_age = w_front_v.z;
            }
            
            if (max_incoming > 0.01) {
                let flow_in = max_incoming * spread_rate;
                next_vol += flow_in;
                next_id = incoming_id;
                next_age = incoming_age;
            }
        }

        // --- 4. Evaporation & Local Heat Reactions ---
        var local_temp = 0.0;
        var total_weight = 0.0;
        let max_instances = u32(round(u.suns[0].params.y));
        for (var i = 0u; i < max_instances; i = i + 1u) {
            let inst = instances[i];
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

        // Apply Evaporation based on ID
        if (next_id > 0.0 && next_vol > 0.005) {
            var local_evap_rate = self_evap_rate;
            if (next_id == 4.0 && local_temp > 60.0) { local_evap_rate = local_evap_rate * 5.0; }
            
            let evap_scale = select(1.0, 0.02, !sol_below);
            let evaporated = min(next_vol, final_evap * dt * 50.0 * local_evap_rate * evap_scale);
            next_vol -= evaporated;
        }

        // --- 5. Contact Reactions ---
        // 1. Water vs Lava contact at boundaries
        if (next_id == 1.0) { // Water
            let touches_lava = 
                round(w_below_v.x) == 2.0 || round(w_above_v.x) == 2.0 ||
                round(w_left_v.x) == 2.0 || round(w_right_v.x) == 2.0 ||
                round(w_back_v.x) == 2.0 || round(w_front_v.x) == 2.0;
            if (touches_lava) {
                next_vol = max(0.0, next_vol - 0.85 * dt);
            }
        }
        if (next_id == 2.0) { // Lava
            let touches_water = 
                round(w_below_v.x) == 1.0 || round(w_above_v.x) == 1.0 ||
                round(w_left_v.x) == 1.0 || round(w_right_v.x) == 1.0 ||
                round(w_back_v.x) == 1.0 || round(w_front_v.x) == 1.0;
            if (touches_water) {
                next_vol = max(0.0, next_vol - 0.85 * dt);
            }
        }
        // 2. Oil vs fire/lava combustion
        if (next_id == 4.0) { // Oil
            let combusts = 
                round(w_below_v.x) == 2.0 || round(w_above_v.x) == 2.0 ||
                round(w_left_v.x) == 2.0 || round(w_right_v.x) == 2.0 ||
                round(w_back_v.x) == 2.0 || round(w_front_v.x) == 2.0 ||
                local_temp > 120.0;
            if (combusts) {
                next_vol = max(0.0, next_vol - 0.10 * dt);
            }
        }
        // 3. Acid eating solid walls
        if (next_id == 3.0) { // Acid
            let adjacent_to_solid = sol_left || sol_right || sol_back || sol_front || sol_below;
            if (adjacent_to_solid) {
                next_vol = max(0.0, next_vol - 2.20 * dt);
            }
        }

        // --- 6. Ceiling Condensation & mid-air rain ---
        // Gas phase condensation adds to water/acid
        let gas_here = get_gas(local_x, local_y, local_z);
        let gas_id = round(gas_here.x);
        let gas_vol = gas_here.y;
        
        let steam_here = select(0.0, gas_vol, gas_id == 1.0);
        let acid_fog_here = select(0.0, gas_vol, gas_id == 3.0);
        
        var near_ceiling = false;
        var cold_ceiling = false;
        for (var dy = 1; dy <= 7; dy = dy + 1) {
            let ceiling_v = get_voxel(local_x, local_y + dy, local_z);
            if (ceiling_v.y >= 0.9) {
                near_ceiling = true;
                let ceil_mat = round(abs(ceiling_v.y));
                if (ceil_mat == 6.0) {
                    cold_ceiling = true;
                }
                break;
            }
        }
        
        let is_cold = cold_ceiling || (local_temp < 10.0);
        var total_condensed = 0.0;
        
        if (near_ceiling && steam_here >= 0.02) {
            let rate_mult = select(1.0, 2.5, is_cold);
            let ceiling_condensation_rate = 0.10 * u.shadow_ao_quality.w * dt * rate_mult;
            total_condensed = total_condensed + min(steam_here, ceiling_condensation_rate);
        }
        
        let rain_threshold = u.grid_dims.w;
        var rain_condensed = 0.0;
        if (steam_here > rain_threshold) {
            let rain_rate = 3.0 * (1.5 * u.shadow_ao_quality.w + 20.0) * dt * (steam_here - rain_threshold);
            rain_condensed = min(steam_here, rain_rate);
        }
        
        let combined_condensed = total_condensed + rain_condensed;
        if (combined_condensed > 0.0) {
            if (next_id == 0.0 || next_id == 1.0) {
                next_id = 1.0;
                next_vol = next_vol + combined_condensed * 1.5;
            }
        }
        
        if (near_ceiling && acid_fog_here >= 0.02) {
            let rate_mult = select(1.0, 2.5, is_cold);
            let acid_condensation_rate = 0.008 * u.shadow_ao_quality.w * dt * rate_mult;
            let acid_condensed = min(acid_fog_here, acid_condensation_rate);
            if (acid_condensed > 0.0) {
                if (next_id == 0.0 || next_id == 3.0) {
                    next_id = 3.0;
                    next_vol = next_vol + acid_condensed * 0.40;
                }
            }
        }

        if (next_vol <= 0.005) {
            next_id = 0.0;
            next_vol = 0.0;
            next_age = 0.0;
        }

        // Tick Age
        if (next_id > 0.0) {
            next_age = next_age + dt;
        }

        // Resolve sleep state (if volume change is microscopic, put to sleep!)
        var next_sleep = 0.0;
        if (abs(next_vol - self_vol) < 0.0001) {
            next_sleep = 1.0;
        }

        water = vec4<f32>(next_id, clamp(next_vol, 0.0, 1.0), next_age, next_sleep);
    }
}
