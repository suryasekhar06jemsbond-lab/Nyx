module nycore {
    fn clamp_int(v, lo, hi) {
        if (v < lo) {
            return lo;
        }
        if (v > hi) {
            return hi;
        }
        return v;
    }

    fn metric(label, value, unit, hint) {
        return {
            label: label,
            value: str(value),
            unit: unit,
            hint: hint
        };
    }

    fn build_metrics(seed) {
        let safe_seed = clamp_int(seed, 1, 999999);
        let fps = 120 + (safe_seed % 71);
        let route_p50 = 6 + (safe_seed % 19);
        let edge_regions = 8 + (safe_seed % 14);
        let active_pods = 180 + (safe_seed % 230);

        return [
            metric("Render Budget", fps, "fps", "nyrender + nyanim pipeline"),
            metric("Route Latency", route_p50, "ms", "nyweb dispatch p50"),
            metric("Edge Regions", edge_regions, "zones", "nynet replication mesh"),
            metric("Live Pods", active_pods, "pods", "nycore orchestration")
        ];
    }

    fn release_stream(seed) {
        let safe_seed = clamp_int(seed, 1, 999999);
        let seq = [];
        let i = 0;
        while (i < 4) {
            let wave = 1 + i;
            let score = 70 + ((safe_seed + i * 17) % 30);
            push(seq, {
                title: "Wave " + str(wave) + " rollout",
                score: str(score) + "%",
                detail: "policy gates + canary + rollback checkpoints"
            });
            i = i + 1;
        }
        return seq;
    }

    fn banner(seed) {
        let safe_seed = clamp_int(seed, 1, 999999);
        let phase = safe_seed % 3;
        if (phase == 0) {
            return "Adaptive rendering and deterministic simulation are locked.";
        }
        if (phase == 1) {
            return "Hot paths are profiled, traced, and hardened for release traffic.";
        }
        return "Engine graph is synchronized for graphics, AI, and network ticks.";
    }
}
