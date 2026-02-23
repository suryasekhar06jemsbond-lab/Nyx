module nyai {
    fn card(name, lane, detail, state) {
        return {
            name: name,
            lane: lane,
            detail: detail,
            state: state
        };
    }

    fn engine_cards(seed) {
        let cards = [];
        let parity = seed % 2;
        let net_state = "stable";
        if (parity == 0) {
            net_state = "adaptive";
        }

        push(cards, card(
            "nyweb",
            "routing + templates",
            "typed route contracts and deterministic response graph",
            "stable"
        ));

        push(cards, card(
            "nyrender",
            "visual compute",
            "multi-layer shader themes and runtime tier mapping",
            "stable"
        ));

        push(cards, card(
            "nyanim",
            "motion system",
            "frame budget aware timeline + stagger choreography",
            "stable"
        ));

        push(cards, card(
            "nynet",
            "transport mesh",
            "latency-aware fanout with packet loss visibility",
            net_state
        ));

        push(cards, card(
            "nycore",
            "ops and control plane",
            "release gates, policy checks, and environment snapshots",
            "stable"
        ));

        return cards;
    }

    fn headline(seed) {
        let rank = seed % 4;
        if (rank == 0) {
            return "Engine-aware web runtime with synchronized render and network lanes.";
        }
        if (rank == 1) {
            return "Unified Nyx stack for UI, routing, motion, and deployment control.";
        }
        if (rank == 2) {
            return "High-signal observability fused with deterministic UI composition.";
        }
        return "One-language web platform orchestrated across Nyx engines.";
    }
}
