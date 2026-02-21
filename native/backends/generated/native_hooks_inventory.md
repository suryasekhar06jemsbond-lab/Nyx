# Native Hook Inventory

Generated from NYX engine declarations.

| Function | Return (NYX) | Return (C) | Params | Source |
|---|---|---|---|---|
| `native_ai_frame_time_ms` | `Float` | `double` | - | `engines/nyai/nyai.ny:831` |
| `native_anim_state_sync_ok` | `Bool` | `int` | - | `engines/nyanim/nyanim.ny:608` |
| `native_anim_update_ms` | `Float` | `double` | - | `engines/nyanim/nyanim.ny:607` |
| `native_asset_has_changed` | `bool` | `int` | path: str -> const char * | `engines/nygame/nygame.ny:1778` |
| `native_asset_load_audio` | `Result<AudioBuffer, Error>` | `void *` | path: str -> const char * | `engines/nygame/nygame.ny:1777` |
| `native_asset_load_font` | `Result<Font, Error>` | `void *` | path: str -> const char *<br>size: i32 -> long long | `engines/nygame/nygame.ny:1776` |
| `native_asset_load_mesh` | `Result<Mesh, Error>` | `void *` | path: str -> const char * | `engines/nygame/nygame.ny:1773` |
| `native_asset_load_model` | `Result<Model, Error>` | `void *` | path: str -> const char * | `engines/nygame/nygame.ny:1774` |
| `native_asset_load_shader` | `Result<Shader, Error>` | `void *` | path: str -> const char * | `engines/nygame/nygame.ny:1775` |
| `native_asset_load_texture` | `Result<Texture, Error>` | `void *` | path: str -> const char * | `engines/nygame/nygame.ny:1772` |
| `native_audio_add_filter` | `void` | `void` | source_id: u32 -> long long<br>filter_type: FilterType -> void *<br>frequency: f32 -> double<br>q: f32 -> double | `engines/nygame/nygame.ny:1787` |
| `native_audio_add_reverb` | `void` | `void` | source_id: u32 -> long long<br>room_size: f32 -> double<br>damping: f32 -> double | `engines/nygame/nygame.ny:1786` |
| `native_audio_backend_alive` | `Bool` | `int` | backend: String -> const char * | `engines/nyaudio/nyaudio.ny:678` |
| `native_audio_create_context` | `AudioContext` | `void *` | - | `engines/nygame/nygame.ny:1780` |
| `native_audio_dsp_time_ms` | `Float` | `double` | - | `engines/nyaudio/nyaudio.ny:679` |
| `native_audio_integrated_lufs` | `Float` | `double` | - | `engines/nyaudio/nyaudio.ny:681` |
| `native_audio_load_buffer` | `Result<AudioBuffer, Error>` | `void *` | path: str -> const char * | `engines/nygame/nygame.ny:1781` |
| `native_audio_play` | `void` | `void` | source_id: u32 -> long long | `engines/nygame/nygame.ny:1782` |
| `native_audio_set_listener` | `void` | `void` | position: Vec3 -> void *<br>forward: Vec3 -> void *<br>up: Vec3 -> void * | `engines/nygame/nygame.ny:1785` |
| `native_audio_set_master_volume` | `void` | `void` | volume: f32 -> double | `engines/nygame/nygame.ny:1784` |
| `native_audio_stop` | `void` | `void` | source_id: u32 -> long long | `engines/nygame/nygame.ny:1783` |
| `native_audio_trace_occlusion` | `Float` | `double` | source_id: String -> const char *<br>lx: Float -> double<br>ly: Float -> double<br>lz: Float -> double | `engines/nyaudio/nyaudio.ny:677` |
| `native_audio_voice_peers` | `Int` | `long long` | - | `engines/nyaudio/nyaudio.ny:680` |
| `native_input_capture_mouse` | `void` | `void` | - | `engines/nygame/nygame.ny:1769` |
| `native_input_release_mouse` | `void` | `void` | - | `engines/nygame/nygame.ny:1770` |
| `native_nyai_build_hybrid_from_intent` | `Bytes` | `NyxBytes` | intent: String -> const char * | `engines/nyai/nyai.ny:981` |
| `native_nyai_run_sandbox` | `Bytes` | `NyxBytes` | step_count: Int -> long long | `engines/nyai/nyai.ny:982` |
| `native_nyanim_adapt_to_physics` | `String` | `const char *` | clip_id: String -> const char *<br>slope: Float -> double<br>impact: Float -> double<br>partial_ragdoll: Float -> double | `engines/nyanim/nyanim.ny:708` |
| `native_nyanim_synthesize_intent` | `Bytes` | `NyxBytes` | intent: String -> const char *<br>gait: Float -> double<br>urgency: Float -> double | `engines/nyanim/nyanim.ny:707` |
| `native_nyaudio_compile_zone_graph` | `Bytes` | `NyxBytes` | zone_count: Int -> long long<br>edge_count: Int -> long long | `engines/nyaudio/nyaudio.ny:797` |
| `native_nyaudio_resolve_music_state` | `List<String>` | `NyxStringList` | state: String -> const char *<br>intensity: Float -> double | `engines/nyaudio/nyaudio.ny:798` |
| `native_nycore_compile_nocode_pipeline` | `Bytes` | `NyxBytes` | graph_blob: Bytes -> NyxBytes<br>layout_blob: Bytes -> NyxBytes<br>serialization_blob: Bytes -> NyxBytes<br>replication_blob: Bytes -> NyxBytes | `engines/nycore/nycore.ny:1097` |
| `native_nycore_compile_schema_layout` | `Bytes` | `NyxBytes` | component_count: Int -> long long<br>constraint_count: Int -> long long | `engines/nycore/nycore.ny:1093` |
| `native_nycore_compile_schema_replication` | `Bytes` | `NyxBytes` | component_count: Int -> long long<br>constraint_count: Int -> long long | `engines/nycore/nycore.ny:1095` |
| `native_nycore_compile_schema_serialization` | `Bytes` | `NyxBytes` | component_count: Int -> long long<br>constraint_count: Int -> long long | `engines/nycore/nycore.ny:1094` |
| `native_nycore_compile_visual_graph` | `Bytes` | `NyxBytes` | system_count: Int -> long long<br>dependency_count: Int -> long long<br>flow_count: Int -> long long | `engines/nycore/nycore.ny:1092` |
| `native_nycore_cpu_count` | `Int` | `long long` | - | `engines/nycore/nycore.ny:351` |
| `native_nycore_detect_isa` | `String` | `const char *` | - | `engines/nycore/nycore.ny:816` |
| `native_nycore_encode` | `Bytes` | `NyxBytes` | schema_id: String -> const char *<br>value_count: Int -> long long | `engines/nycore/nycore.ny:672` |
| `native_nycore_fragmentation_pct` | `Float` | `double` | - | `engines/nycore/nycore.ny:818` |
| `native_nycore_frame_ms` | `Float` | `double` | - | `engines/nycore/nycore.ny:819` |
| `native_nycore_memory_mb` | `Int` | `long long` | - | `engines/nycore/nycore.ny:352` |
| `native_nycore_self_optimize` | `void` | `void` | frame_ms: Float -> double<br>cpu_pct: Float -> double<br>cache_miss_pct: Float -> double<br>auto_parallel: Bool -> int<br>auto_simd: Bool -> int<br>dynamic_merge: Bool -> int | `engines/nycore/nycore.ny:1096` |
| `native_nycore_simd_dot4` | `Float` | `double` | isa: String -> const char *<br>ax: Float -> double<br>ay: Float -> double<br>az: Float -> double<br>aw: Float -> double<br>bx: Float -> double<br>by: Float -> double<br>bz: Float -> double<br>bw: Float -> double | `engines/nycore/nycore.ny:817` |
| `native_nycore_validate_nocode_pipeline` | `Bool` | `int` | - | `engines/nycore/nycore.ny:1098` |
| `native_nygame_bind_engine` | `void` | `void` | name: str -> const char *<br>slot: str -> const char * | `engines/nygame/nygame.ny:2034` |
| `native_nygame_enable_telemetry` | `void` | `void` | name: str -> const char * | `engines/nygame/nygame.ny:2039` |
| `native_nygame_mount_engine` | `bool` | `int` | name: str -> const char *<br>enabled: bool -> int | `engines/nygame/nygame.ny:2033` |
| `native_nygame_report_capability_validation` | `void` | `void` | ok: bool -> int | `engines/nygame/nygame.ny:2042` |
| `native_nygame_report_production_validation` | `void` | `void` | ok: bool -> int | `engines/nygame/nygame.ny:2043` |
| `native_nygame_report_sync` | `void` | `void` | ok: bool -> int | `engines/nygame/nygame.ny:2037` |
| `native_nygame_set_engine_profile` | `void` | `void` | name: str -> const char *<br>profile: str -> const char * | `engines/nygame/nygame.ny:2038` |
| `native_nygame_shutdown_engine` | `void` | `void` | name: str -> const char * | `engines/nygame/nygame.ny:2036` |
| `native_nygame_tick_engine` | `void` | `void` | name: str -> const char *<br>dt: f32 -> double | `engines/nygame/nygame.ny:2035` |
| `native_nygame_verify_engine_capability` | `bool` | `int` | name: str -> const char *<br>capability: str -> const char * | `engines/nygame/nygame.ny:2040` |
| `native_nygame_verify_engine_profile` | `bool` | `int` | name: str -> const char *<br>profile: str -> const char * | `engines/nygame/nygame.ny:2041` |
| `native_nylogic_compile_graph` | `Bytes` | `NyxBytes` | node_count: Int -> long long<br>edge_count: Int -> long long | `engines/nylogic/nylogic.ny:480` |
| `native_nylogic_decode_rule` | `String` | `const char *` | rule_blob: Bytes -> NyxBytes | `engines/nylogic/nylogic.ny:478` |
| `native_nylogic_execute` | `void` | `void` | action: String -> const char *<br>payload: Bytes -> NyxBytes | `engines/nylogic/nylogic.ny:481` |
| `native_nylogic_generate_rule` | `Bytes` | `NyxBytes` | prompt: String -> const char * | `engines/nylogic/nylogic.ny:477` |
| `native_nylogic_mutate` | `Bool` | `int` | rule_id: String -> const char *<br>patch_blob: Bytes -> NyxBytes | `engines/nylogic/nylogic.ny:484` |
| `native_nylogic_optimize` | `void` | `void` | frame_ms: Float -> double<br>target_ms: Float -> double | `engines/nylogic/nylogic.ny:482` |
| `native_nylogic_profile_ms` | `Float` | `double` | - | `engines/nylogic/nylogic.ny:483` |
| `native_nylogic_validate` | `Bool` | `int` | rule_id: String -> const char *<br>condition_count: Int -> long long<br>trigger_count: Int -> long long | `engines/nylogic/nylogic.ny:479` |
| `native_nynet_autodiscover_replication` | `Bytes` | `NyxBytes` | component_count: Int -> long long<br>bandwidth_kbps: Int -> long long | `engines/nynet/nynet.ny:887` |
| `native_nynet_build_interest_zones` | `Bytes` | `NyxBytes` | entity_count: Int -> long long | `engines/nynet/nynet.ny:888` |
| `native_nynet_checksum` | `String` | `const char *` | frame_id: Int -> long long<br>world_blob: Bytes -> NyxBytes | `engines/nynet/nynet.ny:317` |
| `native_nynet_packet_loss_pct` | `Float` | `double` | - | `engines/nynet/nynet.ny:741` |
| `native_nynet_tick_ms` | `Float` | `double` | - | `engines/nynet/nynet.ny:740` |
| `native_nynet_validate_desync` | `Bool` | `int` | frame: Int -> long long<br>local_checksum: String -> const char *<br>remote_checksum: String -> const char * | `engines/nynet/nynet.ny:889` |
| `native_nyphysics_apply_template` | `void` | `void` | template_id: String -> const char * | `engines/nyphysics/nyphysics.ny:1141` |
| `native_nyphysics_auto_tune` | `void` | `void` | telemetry_blob: Bytes -> NyxBytes | `engines/nyphysics/nyphysics.ny:1142` |
| `native_nyphysics_compile_constraint_graph` | `Bytes` | `NyxBytes` | node_count: Int -> long long<br>edge_count: Int -> long long | `engines/nyphysics/nyphysics.ny:1140` |
| `native_nyphysics_compile_nocode_bundle` | `Bytes` | `NyxBytes` | graph_blob: Bytes -> NyxBytes<br>fracture_blob: Bytes -> NyxBytes<br>template_id: String -> const char * | `engines/nyphysics/nyphysics.ny:1144` |
| `native_nyphysics_generate_fracture_rules` | `Bytes` | `NyxBytes` | material_count: Int -> long long | `engines/nyphysics/nyphysics.ny:1143` |
| `native_nyrender_apply_tier` | `void` | `void` | tier: String -> const char * | `engines/nyrender/nyrender.ny:1326` |
| `native_nyrender_compile_material_graph` | `Bytes` | `NyxBytes` | node_count: Int -> long long<br>layer_count: Int -> long long | `engines/nyrender/nyrender.ny:1323` |
| `native_nyrender_compile_pipeline_graph` | `Bytes` | `NyxBytes` | pass_count: Int -> long long<br>edge_count: Int -> long long | `engines/nyrender/nyrender.ny:1325` |
| `native_nyrender_generate_material_from_prompt` | `Bytes` | `NyxBytes` | prompt: String -> const char * | `engines/nyrender/nyrender.ny:1324` |
| `native_nyrender_register_material_blob` | `void` | `void` | material_id: String -> const char *<br>graph_blob: Bytes -> NyxBytes | `engines/nyrender/nyrender.ny:1327` |
| `native_nyworld_compile_world_rules` | `Bytes` | `NyxBytes` | rule_count: Int -> long long | `engines/nyworld/nyworld.ny:987` |
| `native_nyworld_predict_streaming` | `List<String>` | `NyxStringList` | profile_blob: Bytes -> NyxBytes | `engines/nyworld/nyworld.ny:988` |
| `native_nyworld_simulate_economy` | `Bytes` | `NyxBytes` | tick_index: Int -> long long | `engines/nyworld/nyworld.ny:989` |
| `native_physics_boot` | `void` | `void` | - | `engines/nyphysics/nyphysics.ny:485` |
| `native_physics_checksum` | `String` | `const char *` | frame: Int -> long long<br>blob: Bytes -> NyxBytes | `engines/nyphysics/nyphysics.ny:793` |
| `native_physics_query_step_ms` | `Float` | `double` | - | `engines/nyphysics/nyphysics.ny:927` |
| `native_physics_set_float_mode` | `void` | `void` | mode: String -> const char * | `engines/nyphysics/nyphysics.ny:926` |
| `native_physics_shutdown` | `void` | `void` | - | `engines/nyphysics/nyphysics.ny:486` |
| `native_physics_validate_frame` | `Bool` | `int` | frame: Int -> long long<br>state_blob: Bytes -> NyxBytes | `engines/nyphysics/nyphysics.ny:928` |
| `native_render_boot` | `void` | `void` | backend: String -> const char *<br>width: Int -> long long<br>height: Int -> long long | `engines/nyrender/nyrender.ny:609` |
| `native_render_query_gpu_memory_mb` | `Int` | `long long` | - | `engines/nyrender/nyrender.ny:1104` |
| `native_render_query_gpu_time_ms` | `Float` | `double` | - | `engines/nyrender/nyrender.ny:1105` |
| `native_render_shutdown` | `void` | `void` | - | `engines/nyrender/nyrender.ny:610` |
| `native_renderer_clear` | `void` | `void` | r: f32 -> double<br>g: f32 -> double<br>b: f32 -> double<br>a: f32 -> double | `engines/nygame/nygame.ny:1767` |
| `native_renderer_set_viewport` | `void` | `void` | x: i32 -> long long<br>y: i32 -> long long<br>width: i32 -> long long<br>height: i32 -> long long | `engines/nygame/nygame.ny:1766` |
| `native_time_get_ticks` | `u64` | `long long` | - | `engines/nygame/nygame.ny:1789` |
| `native_window_close` | `void` | `void` | handle: WindowHandle -> void * | `engines/nygame/nygame.ny:1759` |
| `native_window_create` | `WindowHandle` | `void *` | width: i32 -> long long<br>height: i32 -> long long<br>title: str -> const char * | `engines/nygame/nygame.ny:1752` |
| `native_window_get_dpi` | `f32` | `double` | - | `engines/nygame/nygame.ny:1761` |
| `native_window_get_refresh_rate` | `i32` | `long long` | - | `engines/nygame/nygame.ny:1762` |
| `native_window_get_size` | `void` | `void` | arg0: ) -> (i32, i32 -> void * | `engines/nygame/nygame.ny:1755` |
| `native_window_is_active` | `bool` | `int` | - | `engines/nygame/nygame.ny:1760` |
| `native_window_maximize` | `void` | `void` | handle: WindowHandle -> void * | `engines/nygame/nygame.ny:1757` |
| `native_window_minimize` | `void` | `void` | handle: WindowHandle -> void * | `engines/nygame/nygame.ny:1756` |
| `native_window_restore` | `void` | `void` | handle: WindowHandle -> void * | `engines/nygame/nygame.ny:1758` |
| `native_window_set_fullscreen` | `void` | `void` | handle: WindowHandle -> void *<br>enabled: bool -> int | `engines/nygame/nygame.ny:1753` |
| `native_window_set_icon` | `void` | `void` | path: str -> const char * | `engines/nygame/nygame.ny:1763` |
| `native_window_set_title` | `void` | `void` | handle: WindowHandle -> void *<br>title: str -> const char * | `engines/nygame/nygame.ny:1754` |
| `native_world_gpu_memory_used_mb` | `Int` | `long long` | - | `engines/nyworld/nyworld.ny:400` |
| `native_world_noise` | `Float` | `double` | x: Float -> double<br>y: Float -> double<br>octaves: Int -> long long | `engines/nyworld/nyworld.ny:399` |
| `native_world_serialize` | `Bytes` | `NyxBytes` | revision: Int -> long long<br>records: Int -> long long | `engines/nyworld/nyworld.ny:684` |
| `native_world_stream_latency_ms` | `Float` | `double` | - | `engines/nyworld/nyworld.ny:825` |
