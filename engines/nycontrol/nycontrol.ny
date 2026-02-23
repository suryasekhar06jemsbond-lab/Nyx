# ============================================================
# NYCONTROL - Nyx Real-Time Control Engine
# ============================================================
# Deterministic execution, low-latency event loop, sensor
# fusion, PID controllers, real-time signal processing,
# and hardware I/O integration. Hard real-time performance.

let VERSION = "1.0.0";

# ============================================================
# DETERMINISTIC EXECUTION
# ============================================================

pub mod deterministic {
    pub class RealtimeConfig {
        pub let priority: Int;
        pub let cpu_affinity: List<Int>;
        pub let stack_size_bytes: Int;
        pub let deadline_us: Int;
        pub let preemptive: Bool;

        pub fn new() -> Self {
            return Self {
                priority: 99, cpu_affinity: [0],
                stack_size_bytes: 65536, deadline_us: 1000,
                preemptive: true
            };
        }
    }

    pub class RealtimeTask {
        pub let name: String;
        pub let config: RealtimeConfig;
        pub let handler: Fn;
        pub let period_us: Int;
        pub let handle: Int?;
        pub let stats: TaskStats;

        pub fn new(name: String, period_us: Int, handler: Fn) -> Self {
            return Self {
                name: name, config: RealtimeConfig::new(),
                handler: handler, period_us: period_us,
                handle: null, stats: TaskStats::new()
            };
        }

        pub fn with_config(self, config: RealtimeConfig) -> Self {
            self.config = config;
            return self;
        }

        pub fn start(self) {
            self.handle = native_ctrl_rt_task_start(self.name, self.period_us, self.handler, self.config);
        }

        pub fn stop(self) {
            if self.handle != null {
                native_ctrl_rt_task_stop(self.handle);
            }
        }

        pub fn get_stats(self) -> TaskStats {
            if self.handle != null {
                self.stats = native_ctrl_rt_task_stats(self.handle);
            }
            return self.stats;
        }
    }

    pub class TaskStats {
        pub let executions: Int;
        pub let min_latency_us: Float;
        pub let max_latency_us: Float;
        pub let avg_latency_us: Float;
        pub let jitter_us: Float;
        pub let deadline_misses: Int;
        pub let overruns: Int;

        pub fn new() -> Self {
            return Self {
                executions: 0, min_latency_us: 0.0,
                max_latency_us: 0.0, avg_latency_us: 0.0,
                jitter_us: 0.0, deadline_misses: 0, overruns: 0
            };
        }
    }

    pub class RealtimeScheduler {
        pub let tasks: List<RealtimeTask>;
        pub let running: Bool;

        pub fn new() -> Self {
            return Self { tasks: [], running: false };
        }

        pub fn add_task(self, task: RealtimeTask) {
            self.tasks.push(task);
        }

        pub fn start_all(self) {
            native_ctrl_lock_memory();
            for task in self.tasks { task.start(); }
            self.running = true;
        }

        pub fn stop_all(self) {
            for task in self.tasks { task.stop(); }
            self.running = false;
        }

        pub fn report(self) -> List<Map<String, Any>> {
            let results = [];
            for task in self.tasks {
                let stats = task.get_stats();
                results.push({
                    "name": task.name,
                    "period_us": task.period_us,
                    "executions": stats.executions,
                    "avg_latency_us": stats.avg_latency_us,
                    "max_latency_us": stats.max_latency_us,
                    "jitter_us": stats.jitter_us,
                    "deadline_misses": stats.deadline_misses
                });
            }
            return results;
        }
    }
}

# ============================================================
# LOW-LATENCY EVENT LOOP
# ============================================================

pub mod event_loop {
    pub class RTEvent {
        pub let type_name: String;
        pub let data: Any;
        pub let timestamp_ns: Int;
        pub let priority: Int;

        pub fn new(type_name: String, data: Any, priority: Int) -> Self {
            return Self {
                type_name: type_name, data: data,
                timestamp_ns: native_ctrl_time_ns(),
                priority: priority
            };
        }
    }

    pub class RTEventLoop {
        pub let handlers: Map<String, List<Fn>>;
        pub let running: Bool;
        pub let poll_interval_us: Int;
        pub let handle: Int?;

        pub fn new(poll_interval_us: Int) -> Self {
            return Self {
                handlers: {}, running: false,
                poll_interval_us: poll_interval_us,
                handle: null
            };
        }

        pub fn on(self, event_type: String, handler: Fn) {
            if not self.handlers.has(event_type) {
                self.handlers[event_type] = [];
            }
            self.handlers[event_type].push(handler);
        }

        pub fn emit(self, event: RTEvent) {
            native_ctrl_event_emit(self.handle, event);
        }

        pub fn start(self) {
            self.handle = native_ctrl_event_loop_start(self.poll_interval_us, self.handlers);
            self.running = true;
        }

        pub fn stop(self) {
            if self.handle != null {
                native_ctrl_event_loop_stop(self.handle);
            }
            self.running = false;
        }
    }
}

# ============================================================
# SENSOR FUSION
# ============================================================

pub mod sensor_fusion {
    pub class SensorReading {
        pub let sensor_id: String;
        pub let values: List<Float>;
        pub let timestamp_ns: Int;
        pub let covariance: List<List<Float>>?;
        pub let valid: Bool;

        pub fn new(sensor_id: String, values: List<Float>) -> Self {
            return Self {
                sensor_id: sensor_id, values: values,
                timestamp_ns: native_ctrl_time_ns(),
                covariance: null, valid: true
            };
        }
    }

    pub class KalmanFilter {
        pub let state: List<Float>;
        pub let covariance: List<List<Float>>;
        pub let process_noise: List<List<Float>>;
        pub let measurement_noise: List<List<Float>>;
        pub let transition: List<List<Float>>;
        pub let measurement_matrix: List<List<Float>>;

        pub fn new(state_dim: Int, meas_dim: Int) -> Self {
            return Self {
                state: native_ctrl_zeros(state_dim),
                covariance: native_ctrl_identity(state_dim),
                process_noise: native_ctrl_identity(state_dim),
                measurement_noise: native_ctrl_identity(meas_dim),
                transition: native_ctrl_identity(state_dim),
                measurement_matrix: native_ctrl_zeros_matrix(meas_dim, state_dim)
            };
        }

        pub fn predict(self, dt: Float) {
            let result = native_ctrl_kalman_predict(self.state, self.covariance, self.transition, self.process_noise, dt);
            self.state = result.state;
            self.covariance = result.covariance;
        }

        pub fn update(self, measurement: List<Float>) {
            let result = native_ctrl_kalman_update(self.state, self.covariance, measurement, self.measurement_matrix, self.measurement_noise);
            self.state = result.state;
            self.covariance = result.covariance;
        }

        pub fn get_state(self) -> List<Float> { return self.state; }
    }

    pub class ExtendedKalmanFilter {
        pub let state: List<Float>;
        pub let covariance: List<List<Float>>;
        pub let process_fn: Fn;
        pub let measurement_fn: Fn;
        pub let jacobian_f: Fn;
        pub let jacobian_h: Fn;

        pub fn new(state_dim: Int) -> Self {
            return Self {
                state: native_ctrl_zeros(state_dim),
                covariance: native_ctrl_identity(state_dim),
                process_fn: |s, dt| s,
                measurement_fn: |s| s,
                jacobian_f: |s, dt| native_ctrl_identity(state_dim),
                jacobian_h: |s| native_ctrl_identity(state_dim)
            };
        }

        pub fn predict(self, dt: Float) {
            self.state = self.process_fn(self.state, dt);
            let F = self.jacobian_f(self.state, dt);
            self.covariance = native_ctrl_ekf_predict_cov(self.covariance, F);
        }

        pub fn update(self, measurement: List<Float>) {
            let result = native_ctrl_ekf_update(self.state, self.covariance, measurement, self.measurement_fn, self.jacobian_h);
            self.state = result.state;
            self.covariance = result.covariance;
        }
    }

    pub class ComplementaryFilter {
        pub let alpha: Float;
        pub let state: List<Float>;

        pub fn new(alpha: Float, state_dim: Int) -> Self {
            return Self { alpha: alpha, state: native_ctrl_zeros(state_dim) };
        }

        pub fn update(self, high_freq: List<Float>, low_freq: List<Float>) {
            for i in 0..self.state.len() {
                self.state[i] = self.alpha * high_freq[i] + (1.0 - self.alpha) * low_freq[i];
            }
        }
    }

    pub class SensorFusionEngine {
        pub let filters: Map<String, KalmanFilter>;
        pub let readings: Map<String, List<SensorReading>>;
        pub let buffer_size: Int;

        pub fn new() -> Self {
            return Self { filters: {}, readings: {}, buffer_size: 100 };
        }

        pub fn register_sensor(self, sensor_id: String, state_dim: Int, meas_dim: Int) {
            self.filters[sensor_id] = KalmanFilter::new(state_dim, meas_dim);
            self.readings[sensor_id] = [];
        }

        pub fn process(self, reading: SensorReading) -> List<Float> {
            if not reading.valid { return []; }
            let filter = self.filters.get(reading.sensor_id);
            if filter == null { return reading.values; }

            let readings_list = self.readings[reading.sensor_id];
            readings_list.push(reading);
            if readings_list.len() > self.buffer_size { readings_list.remove(0); }

            let dt = 0.001;
            if readings_list.len() > 1 {
                let prev = readings_list[readings_list.len() - 2];
                dt = (reading.timestamp_ns - prev.timestamp_ns) as Float / 1e9;
            }

            filter.predict(dt);
            filter.update(reading.values);
            return filter.get_state();
        }
    }
}

# ============================================================
# PID CONTROLLERS
# ============================================================

pub mod pid {
    pub class PIDController {
        pub let kp: Float;
        pub let ki: Float;
        pub let kd: Float;
        pub let setpoint: Float;
        pub let integral: Float;
        pub let prev_error: Float;
        pub let output_min: Float;
        pub let output_max: Float;
        pub let integral_min: Float;
        pub let integral_max: Float;
        pub let derivative_filter: Float;
        pub let prev_derivative: Float;

        pub fn new(kp: Float, ki: Float, kd: Float) -> Self {
            return Self {
                kp: kp, ki: ki, kd: kd,
                setpoint: 0.0, integral: 0.0,
                prev_error: 0.0, output_min: -1e9,
                output_max: 1e9, integral_min: -1e6,
                integral_max: 1e6, derivative_filter: 0.1,
                prev_derivative: 0.0
            };
        }

        pub fn set_target(self, setpoint: Float) {
            self.setpoint = setpoint;
        }

        pub fn set_limits(self, min: Float, max: Float) {
            self.output_min = min;
            self.output_max = max;
        }

        pub fn update(self, measurement: Float, dt: Float) -> Float {
            let error = self.setpoint - measurement;

            self.integral = self.integral + error * dt;
            self.integral = self.integral.clamp(self.integral_min, self.integral_max);

            let raw_derivative = (error - self.prev_error) / dt;
            let derivative = self.derivative_filter * raw_derivative + (1.0 - self.derivative_filter) * self.prev_derivative;
            self.prev_derivative = derivative;

            let output = self.kp * error + self.ki * self.integral + self.kd * derivative;
            output = output.clamp(self.output_min, self.output_max);

            self.prev_error = error;
            return output;
        }

        pub fn reset(self) {
            self.integral = 0.0;
            self.prev_error = 0.0;
            self.prev_derivative = 0.0;
        }
    }

    pub class CascadePID {
        pub let outer: PIDController;
        pub let inner: PIDController;

        pub fn new(outer: PIDController, inner: PIDController) -> Self {
            return Self { outer: outer, inner: inner };
        }

        pub fn update(self, outer_measurement: Float, inner_measurement: Float, dt: Float) -> Float {
            let inner_setpoint = self.outer.update(outer_measurement, dt);
            self.inner.set_target(inner_setpoint);
            return self.inner.update(inner_measurement, dt);
        }
    }

    pub class PIDAutoTuner {
        pub fn tune(process_fn: Fn, initial_setpoint: Float, duration_s: Float) -> Map<String, Float> {
            return native_ctrl_pid_autotune(process_fn, initial_setpoint, duration_s);
        }
    }
}

# ============================================================
# SIGNAL PROCESSING
# ============================================================

pub mod signal {
    pub class SignalBuffer {
        pub let data: List<Float>;
        pub let sample_rate: Float;
        pub let capacity: Int;

        pub fn new(sample_rate: Float, capacity: Int) -> Self {
            return Self { data: [], sample_rate: sample_rate, capacity: capacity };
        }

        pub fn push(self, sample: Float) {
            self.data.push(sample);
            if self.data.len() > self.capacity { self.data.remove(0); }
        }

        pub fn push_batch(self, samples: List<Float>) {
            for s in samples { self.push(s); }
        }

        pub fn len(self) -> Int { return self.data.len(); }
    }

    pub class FIRFilter {
        pub let coefficients: List<Float>;
        pub let buffer: List<Float>;

        pub fn new(coefficients: List<Float>) -> Self {
            return Self {
                coefficients: coefficients,
                buffer: native_ctrl_zeros(coefficients.len())
            };
        }

        pub fn process(self, sample: Float) -> Float {
            self.buffer.remove(0);
            self.buffer.push(sample);
            let output = 0.0;
            for i in 0..self.coefficients.len() {
                output = output + self.coefficients[i] * self.buffer[i];
            }
            return output;
        }

        pub fn low_pass(sample_rate: Float, cutoff: Float, order: Int) -> Self {
            let coeffs = native_ctrl_design_fir_lowpass(sample_rate, cutoff, order);
            return Self::new(coeffs);
        }

        pub fn high_pass(sample_rate: Float, cutoff: Float, order: Int) -> Self {
            let coeffs = native_ctrl_design_fir_highpass(sample_rate, cutoff, order);
            return Self::new(coeffs);
        }

        pub fn band_pass(sample_rate: Float, low: Float, high: Float, order: Int) -> Self {
            let coeffs = native_ctrl_design_fir_bandpass(sample_rate, low, high, order);
            return Self::new(coeffs);
        }
    }

    pub class IIRFilter {
        pub let a_coeffs: List<Float>;
        pub let b_coeffs: List<Float>;
        pub let x_buf: List<Float>;
        pub let y_buf: List<Float>;

        pub fn new(b: List<Float>, a: List<Float>) -> Self {
            return Self {
                a_coeffs: a, b_coeffs: b,
                x_buf: native_ctrl_zeros(b.len()),
                y_buf: native_ctrl_zeros(a.len())
            };
        }

        pub fn process(self, sample: Float) -> Float {
            return native_ctrl_iir_process(self.b_coeffs, self.a_coeffs, self.x_buf, self.y_buf, sample);
        }

        pub fn butterworth(order: Int, sample_rate: Float, cutoff: Float) -> Self {
            let result = native_ctrl_design_butterworth(order, sample_rate, cutoff);
            return Self::new(result.b, result.a);
        }
    }

    pub class FFT {
        pub fn forward(data: List<Float>) -> List<List<Float>> {
            return native_ctrl_fft(data);
        }

        pub fn inverse(spectrum: List<List<Float>>) -> List<Float> {
            return native_ctrl_ifft(spectrum);
        }

        pub fn power_spectrum(data: List<Float>) -> List<Float> {
            return native_ctrl_power_spectrum(data);
        }

        pub fn spectrogram(data: List<Float>, window_size: Int, hop_size: Int) -> List<List<Float>> {
            return native_ctrl_spectrogram(data, window_size, hop_size);
        }
    }
}

# ============================================================
# HARDWARE I/O
# ============================================================

pub mod hardware_io {
    pub class GPIOPin {
        pub let pin: Int;
        pub let direction: String;
        pub let handle: Int?;

        pub fn new(pin: Int, direction: String) -> Self {
            return Self { pin: pin, direction: direction, handle: null };
        }

        pub fn open(self) {
            self.handle = native_ctrl_gpio_open(self.pin, self.direction);
        }

        pub fn read(self) -> Int {
            return native_ctrl_gpio_read(self.handle);
        }

        pub fn write(self, value: Int) {
            native_ctrl_gpio_write(self.handle, value);
        }

        pub fn close(self) {
            if self.handle != null { native_ctrl_gpio_close(self.handle); }
        }
    }

    pub class ADC {
        pub let channel: Int;
        pub let resolution_bits: Int;
        pub let reference_voltage: Float;
        pub let handle: Int?;

        pub fn new(channel: Int, resolution: Int, vref: Float) -> Self {
            return Self {
                channel: channel, resolution_bits: resolution,
                reference_voltage: vref, handle: null
            };
        }

        pub fn open(self) {
            self.handle = native_ctrl_adc_open(self.channel, self.resolution_bits);
        }

        pub fn read_raw(self) -> Int {
            return native_ctrl_adc_read(self.handle);
        }

        pub fn read_voltage(self) -> Float {
            let raw = self.read_raw();
            return raw as Float / ((1 << self.resolution_bits) - 1) as Float * self.reference_voltage;
        }

        pub fn close(self) {
            if self.handle != null { native_ctrl_adc_close(self.handle); }
        }
    }

    pub class DAC {
        pub let channel: Int;
        pub let resolution_bits: Int;
        pub let handle: Int?;

        pub fn new(channel: Int, resolution: Int) -> Self {
            return Self { channel: channel, resolution_bits: resolution, handle: null };
        }

        pub fn open(self) {
            self.handle = native_ctrl_dac_open(self.channel, self.resolution_bits);
        }

        pub fn write(self, value: Int) {
            native_ctrl_dac_write(self.handle, value);
        }

        pub fn write_voltage(self, voltage: Float, vref: Float) {
            let raw = ((voltage / vref) * ((1 << self.resolution_bits) - 1) as Float) as Int;
            self.write(raw);
        }

        pub fn close(self) {
            if self.handle != null { native_ctrl_dac_close(self.handle); }
        }
    }

    pub class PWM {
        pub let channel: Int;
        pub let frequency_hz: Float;
        pub let duty_cycle: Float;
        pub let handle: Int?;

        pub fn new(channel: Int, frequency: Float) -> Self {
            return Self { channel: channel, frequency_hz: frequency, duty_cycle: 0.0, handle: null };
        }

        pub fn start(self) {
            self.handle = native_ctrl_pwm_start(self.channel, self.frequency_hz, self.duty_cycle);
        }

        pub fn set_duty(self, duty: Float) {
            self.duty_cycle = duty.clamp(0.0, 1.0);
            native_ctrl_pwm_set_duty(self.handle, self.duty_cycle);
        }

        pub fn set_frequency(self, freq: Float) {
            self.frequency_hz = freq;
            native_ctrl_pwm_set_freq(self.handle, self.frequency_hz);
        }

        pub fn stop(self) {
            if self.handle != null { native_ctrl_pwm_stop(self.handle); }
        }
    }
}

# ============================================================
# CONTROL SYSTEM ORCHESTRATOR
# ============================================================

pub class ControlSystem {
    pub let scheduler: deterministic.RealtimeScheduler;
    pub let event_loop: event_loop.RTEventLoop;
    pub let fusion: sensor_fusion.SensorFusionEngine;

    pub fn new(poll_us: Int) -> Self {
        return Self {
            scheduler: deterministic.RealtimeScheduler::new(),
            event_loop: event_loop.RTEventLoop::new(poll_us),
            fusion: sensor_fusion.SensorFusionEngine::new()
        };
    }

    pub fn start(self) {
        self.scheduler.start_all();
        self.event_loop.start();
    }

    pub fn stop(self) {
        self.event_loop.stop();
        self.scheduler.stop_all();
    }
}

pub fn create_control_system(poll_us: Int) -> ControlSystem {
    return ControlSystem::new(poll_us);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_ctrl_time_ns() -> Int;
native_ctrl_lock_memory();
native_ctrl_rt_task_start(name: String, period: Int, handler: Fn, config: Any) -> Int;
native_ctrl_rt_task_stop(handle: Int);
native_ctrl_rt_task_stats(handle: Int) -> Any;
native_ctrl_event_loop_start(interval: Int, handlers: Map) -> Int;
native_ctrl_event_loop_stop(handle: Int);
native_ctrl_event_emit(handle: Int, event: Any);
native_ctrl_zeros(n: Int) -> List;
native_ctrl_zeros_matrix(rows: Int, cols: Int) -> List;
native_ctrl_identity(n: Int) -> List;
native_ctrl_kalman_predict(state: List, cov: List, trans: List, noise: List, dt: Float) -> Any;
native_ctrl_kalman_update(state: List, cov: List, meas: List, H: List, R: List) -> Any;
native_ctrl_ekf_predict_cov(cov: List, F: List) -> List;
native_ctrl_ekf_update(state: List, cov: List, meas: List, h_fn: Fn, jac_h: Fn) -> Any;
native_ctrl_pid_autotune(process: Fn, setpoint: Float, duration: Float) -> Map;
native_ctrl_design_fir_lowpass(sr: Float, cutoff: Float, order: Int) -> List;
native_ctrl_design_fir_highpass(sr: Float, cutoff: Float, order: Int) -> List;
native_ctrl_design_fir_bandpass(sr: Float, low: Float, high: Float, order: Int) -> List;
native_ctrl_iir_process(b: List, a: List, xbuf: List, ybuf: List, sample: Float) -> Float;
native_ctrl_design_butterworth(order: Int, sr: Float, cutoff: Float) -> Any;
native_ctrl_fft(data: List) -> List;
native_ctrl_ifft(spectrum: List) -> List;
native_ctrl_power_spectrum(data: List) -> List;
native_ctrl_spectrogram(data: List, win: Int, hop: Int) -> List;
native_ctrl_gpio_open(pin: Int, dir: String) -> Int;
native_ctrl_gpio_read(handle: Int) -> Int;
native_ctrl_gpio_write(handle: Int, value: Int);
native_ctrl_gpio_close(handle: Int);
native_ctrl_adc_open(channel: Int, bits: Int) -> Int;
native_ctrl_adc_read(handle: Int) -> Int;
native_ctrl_adc_close(handle: Int);
native_ctrl_dac_open(channel: Int, bits: Int) -> Int;
native_ctrl_dac_write(handle: Int, value: Int);
native_ctrl_dac_close(handle: Int);
native_ctrl_pwm_start(channel: Int, freq: Float, duty: Float) -> Int;
native_ctrl_pwm_set_duty(handle: Int, duty: Float);
native_ctrl_pwm_set_freq(handle: Int, freq: Float);
native_ctrl_pwm_stop(handle: Int);

# ============================================================
# PRODUCTION-READY INFRASTRUCTURE
# ============================================================

pub mod production {

    pub class HealthStatus {
        pub let status: String;
        pub let uptime_ms: Int;
        pub let checks: Map;
        pub let version: String;

        pub fn new() -> Self {
            return Self {
                status: "healthy",
                uptime_ms: 0,
                checks: {},
                version: VERSION
            };
        }

        pub fn is_healthy(self) -> Bool {
            return self.status == "healthy";
        }

        pub fn add_check(self, name: String, passed: Bool, detail: String) {
            self.checks[name] = { "passed": passed, "detail": detail };
            if !passed { self.status = "degraded"; }
        }
    }

    pub class MetricsCollector {
        pub let counters: Map;
        pub let gauges: Map;
        pub let histograms: Map;
        pub let start_time: Int;

        pub fn new() -> Self {
            return Self {
                counters: {},
                gauges: {},
                histograms: {},
                start_time: native_production_time_ms()
            };
        }

        pub fn increment(self, name: String, value: Int) {
            self.counters[name] = (self.counters[name] or 0) + value;
        }

        pub fn gauge_set(self, name: String, value: Float) {
            self.gauges[name] = value;
        }

        pub fn histogram_observe(self, name: String, value: Float) {
            if self.histograms[name] == null { self.histograms[name] = []; }
            self.histograms[name].push(value);
        }

        pub fn snapshot(self) -> Map {
            return {
                "counters": self.counters,
                "gauges": self.gauges,
                "uptime_ms": native_production_time_ms() - self.start_time
            };
        }

        pub fn reset(self) {
            self.counters = {};
            self.gauges = {};
            self.histograms = {};
        }
    }

    pub class Logger {
        pub let level: String;
        pub let buffer: List;
        pub let max_buffer: Int;

        pub fn new(level: String) -> Self {
            return Self { level: level, buffer: [], max_buffer: 10000 };
        }

        pub fn debug(self, msg: String, context: Map?) {
            if self.level == "debug" { self._log("DEBUG", msg, context); }
        }

        pub fn info(self, msg: String, context: Map?) {
            if self.level != "error" and self.level != "warn" {
                self._log("INFO", msg, context);
            }
        }

        pub fn warn(self, msg: String, context: Map?) {
            if self.level != "error" { self._log("WARN", msg, context); }
        }

        pub fn error(self, msg: String, context: Map?) {
            self._log("ERROR", msg, context);
        }

        fn _log(self, lvl: String, msg: String, context: Map?) {
            let entry = {
                "ts": native_production_time_ms(),
                "level": lvl,
                "msg": msg,
                "ctx": context
            };
            self.buffer.push(entry);
            if self.buffer.len() > self.max_buffer {
                self.buffer = self.buffer[self.max_buffer / 2..];
            }
        }

        pub fn flush(self) -> List {
            let out = self.buffer;
            self.buffer = [];
            return out;
        }
    }

    pub class CircuitBreaker {
        pub let state: String;
        pub let failure_count: Int;
        pub let threshold: Int;
        pub let reset_timeout_ms: Int;
        pub let last_failure_time: Int;

        pub fn new(threshold: Int, reset_timeout_ms: Int) -> Self {
            return Self {
                state: "closed",
                failure_count: 0,
                threshold: threshold,
                reset_timeout_ms: reset_timeout_ms,
                last_failure_time: 0
            };
        }

        pub fn allow_request(self) -> Bool {
            if self.state == "closed" { return true; }
            if self.state == "open" {
                let elapsed = native_production_time_ms() - self.last_failure_time;
                if elapsed >= self.reset_timeout_ms {
                    self.state = "half-open";
                    return true;
                }
                return false;
            }
            return true;
        }

        pub fn record_success(self) {
            self.failure_count = 0;
            self.state = "closed";
        }

        pub fn record_failure(self) {
            self.failure_count = self.failure_count + 1;
            self.last_failure_time = native_production_time_ms();
            if self.failure_count >= self.threshold {
                self.state = "open";
            }
        }
    }

    pub class RetryPolicy {
        pub let max_retries: Int;
        pub let base_delay_ms: Int;
        pub let max_delay_ms: Int;
        pub let backoff_multiplier: Float;

        pub fn new(max_retries: Int) -> Self {
            return Self {
                max_retries: max_retries,
                base_delay_ms: 100,
                max_delay_ms: 30000,
                backoff_multiplier: 2.0
            };
        }

        pub fn get_delay(self, attempt: Int) -> Int {
            let delay = self.base_delay_ms;
            for _ in 0..attempt { delay = (delay * self.backoff_multiplier).to_int(); }
            if delay > self.max_delay_ms { delay = self.max_delay_ms; }
            return delay;
        }
    }

    pub class RateLimiter {
        pub let max_requests: Int;
        pub let window_ms: Int;
        pub let requests: List;

        pub fn new(max_requests: Int, window_ms: Int) -> Self {
            return Self { max_requests: max_requests, window_ms: window_ms, requests: [] };
        }

        pub fn allow(self) -> Bool {
            let now = native_production_time_ms();
            self.requests = self.requests.filter(fn(t) { t > now - self.window_ms });
            if self.requests.len() >= self.max_requests { return false; }
            self.requests.push(now);
            return true;
        }
    }

    pub class GracefulShutdown {
        pub let hooks: List;
        pub let timeout_ms: Int;
        pub let is_shutting_down: Bool;

        pub fn new(timeout_ms: Int) -> Self {
            return Self { hooks: [], timeout_ms: timeout_ms, is_shutting_down: false };
        }

        pub fn register(self, name: String, hook: Fn) {
            self.hooks.push({ "name": name, "hook": hook });
        }

        pub fn shutdown(self) {
            self.is_shutting_down = true;
            for entry in self.hooks {
                entry.hook();
            }
        }
    }

    pub class ProductionRuntime {
        pub let health: HealthStatus;
        pub let metrics: MetricsCollector;
        pub let logger: Logger;
        pub let circuit_breaker: CircuitBreaker;
        pub let rate_limiter: RateLimiter;
        pub let shutdown: GracefulShutdown;

        pub fn new() -> Self {
            return Self {
                health: HealthStatus::new(),
                metrics: MetricsCollector::new(),
                logger: Logger::new("info"),
                circuit_breaker: CircuitBreaker::new(5, 30000),
                rate_limiter: RateLimiter::new(1000, 60000),
                shutdown: GracefulShutdown::new(30000)
            };
        }

        pub fn check_health(self) -> HealthStatus {
            self.health.uptime_ms = native_production_time_ms() - self.metrics.start_time;
            return self.health;
        }

        pub fn get_metrics(self) -> Map {
            return self.metrics.snapshot();
        }

        pub fn is_ready(self) -> Bool {
            return self.health.is_healthy() and !self.shutdown.is_shutting_down;
        }
    }
}

native_production_time_ms() -> Int;

# ============================================================
# OBSERVABILITY & ERROR HANDLING
# ============================================================

pub mod observability {

    pub class Span {
        pub let trace_id: String;
        pub let span_id: String;
        pub let parent_id: String?;
        pub let operation: String;
        pub let start_time: Int;
        pub let end_time: Int?;
        pub let tags: Map;
        pub let status: String;

        pub fn new(operation: String, parent_id: String?) -> Self {
            return Self {
                trace_id: native_production_time_ms().to_string(),
                span_id: native_production_time_ms().to_string(),
                parent_id: parent_id,
                operation: operation,
                start_time: native_production_time_ms(),
                end_time: null,
                tags: {},
                status: "ok"
            };
        }

        pub fn set_tag(self, key: String, value: String) {
            self.tags[key] = value;
        }

        pub fn finish(self) {
            self.end_time = native_production_time_ms();
        }

        pub fn finish_with_error(self, error: String) {
            self.end_time = native_production_time_ms();
            self.status = "error";
            self.tags["error"] = error;
        }

        pub fn duration_ms(self) -> Int {
            if self.end_time == null { return 0; }
            return self.end_time - self.start_time;
        }
    }

    pub class Tracer {
        pub let spans: List;
        pub let active_span: Span?;
        pub let service_name: String;

        pub fn new(service_name: String) -> Self {
            return Self { spans: [], active_span: null, service_name: service_name };
        }

        pub fn start_span(self, operation: String) -> Span {
            let parent = if self.active_span != null { self.active_span.span_id } else { null };
            let span = Span::new(operation, parent);
            span.set_tag("service", self.service_name);
            self.active_span = span;
            return span;
        }

        pub fn finish_span(self, span: Span) {
            span.finish();
            self.spans.push(span);
            self.active_span = null;
        }

        pub fn get_traces(self) -> List {
            return self.spans;
        }
    }

    pub class AlertRule {
        pub let name: String;
        pub let condition: Fn;
        pub let severity: String;
        pub let cooldown_ms: Int;
        pub let last_fired: Int;

        pub fn new(name: String, condition: Fn, severity: String) -> Self {
            return Self {
                name: name,
                condition: condition,
                severity: severity,
                cooldown_ms: 60000,
                last_fired: 0
            };
        }

        pub fn evaluate(self, metrics: Map) -> Bool {
            let now = native_production_time_ms();
            if now - self.last_fired < self.cooldown_ms { return false; }
            if self.condition(metrics) {
                self.last_fired = now;
                return true;
            }
            return false;
        }
    }

    pub class AlertManager {
        pub let rules: List;
        pub let alerts: List;

        pub fn new() -> Self {
            return Self { rules: [], alerts: [] };
        }

        pub fn add_rule(self, rule: AlertRule) {
            self.rules.push(rule);
        }

        pub fn evaluate_all(self, metrics: Map) -> List {
            let fired = [];
            for rule in self.rules {
                if rule.evaluate(metrics) {
                    let alert = {
                        "name": rule.name,
                        "severity": rule.severity,
                        "time": native_production_time_ms()
                    };
                    self.alerts.push(alert);
                    fired.push(alert);
                }
            }
            return fired;
        }
    }
}

pub mod error_handling {

    pub class EngineError {
        pub let code: String;
        pub let message: String;
        pub let context: Map;
        pub let timestamp: Int;
        pub let recoverable: Bool;

        pub fn new(code: String, message: String, recoverable: Bool) -> Self {
            return Self {
                code: code,
                message: message,
                context: {},
                timestamp: native_production_time_ms(),
                recoverable: recoverable
            };
        }

        pub fn with_context(self, key: String, value: Any) -> Self {
            self.context[key] = value;
            return self;
        }
    }

    pub class ErrorRegistry {
        pub let errors: List;
        pub let max_errors: Int;

        pub fn new(max_errors: Int) -> Self {
            return Self { errors: [], max_errors: max_errors };
        }

        pub fn record(self, error: EngineError) {
            self.errors.push(error);
            if self.errors.len() > self.max_errors {
                self.errors = self.errors[self.errors.len() - self.max_errors..];
            }
        }

        pub fn get_recent(self, count: Int) -> List {
            let start = if self.errors.len() > count { self.errors.len() - count } else { 0 };
            return self.errors[start..];
        }

        pub fn count_by_code(self, code: String) -> Int {
            return self.errors.filter(fn(e) { e.code == code }).len();
        }
    }

    pub class RecoveryStrategy {
        pub let name: String;
        pub let max_attempts: Int;
        pub let handler: Fn;

        pub fn new(name: String, max_attempts: Int, handler: Fn) -> Self {
            return Self { name: name, max_attempts: max_attempts, handler: handler };
        }
    }

    pub class ErrorHandler {
        pub let registry: ErrorRegistry;
        pub let strategies: Map;
        pub let fallback: Fn?;

        pub fn new() -> Self {
            return Self {
                registry: ErrorRegistry::new(1000),
                strategies: {},
                fallback: null
            };
        }

        pub fn register_strategy(self, code: String, strategy: RecoveryStrategy) {
            self.strategies[code] = strategy;
        }

        pub fn set_fallback(self, handler: Fn) {
            self.fallback = handler;
        }

        pub fn handle(self, error: EngineError) -> Any? {
            self.registry.record(error);
            if error.recoverable and self.strategies[error.code] != null {
                let strategy = self.strategies[error.code];
                return strategy.handler(error);
            }
            if self.fallback != null { return self.fallback(error); }
            return null;
        }
    }
}

# ============================================================
# CONFIGURATION & LIFECYCLE MANAGEMENT
# ============================================================

pub mod config_management {

    pub class EnvConfig {
        pub let values: Map;
        pub let defaults: Map;
        pub let required_keys: List;

        pub fn new() -> Self {
            return Self { values: {}, defaults: {}, required_keys: [] };
        }

        pub fn set_default(self, key: String, value: Any) {
            self.defaults[key] = value;
        }

        pub fn set(self, key: String, value: Any) {
            self.values[key] = value;
        }

        pub fn require(self, key: String) {
            self.required_keys.push(key);
        }

        pub fn get(self, key: String) -> Any? {
            if self.values[key] != null { return self.values[key]; }
            return self.defaults[key];
        }

        pub fn get_int(self, key: String) -> Int {
            let v = self.get(key);
            if v == null { return 0; }
            return v.to_int();
        }

        pub fn get_bool(self, key: String) -> Bool {
            let v = self.get(key);
            if v == null { return false; }
            return v == true or v == "true" or v == "1";
        }

        pub fn validate(self) -> List {
            let missing = [];
            for key in self.required_keys {
                if self.get(key) == null { missing.push(key); }
            }
            return missing;
        }

        pub fn from_map(self, map: Map) {
            for key in map.keys() { self.values[key] = map[key]; }
        }
    }

    pub class FeatureFlag {
        pub let name: String;
        pub let enabled: Bool;
        pub let rollout_pct: Float;
        pub let metadata: Map;

        pub fn new(name: String, enabled: Bool) -> Self {
            return Self { name: name, enabled: enabled, rollout_pct: 100.0, metadata: {} };
        }

        pub fn is_enabled(self) -> Bool {
            return self.enabled;
        }

        pub fn is_enabled_for(self, user_id: String) -> Bool {
            if !self.enabled { return false; }
            if self.rollout_pct >= 100.0 { return true; }
            let hash = user_id.len() % 100;
            return hash < self.rollout_pct.to_int();
        }
    }

    pub class FeatureFlagManager {
        pub let flags: Map;

        pub fn new() -> Self {
            return Self { flags: {} };
        }

        pub fn register(self, flag: FeatureFlag) {
            self.flags[flag.name] = flag;
        }

        pub fn is_enabled(self, name: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled();
        }

        pub fn is_enabled_for(self, name: String, user_id: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled_for(user_id);
        }
    }
}

pub mod lifecycle {

    pub class Phase {
        pub let name: String;
        pub let order: Int;
        pub let handler: Fn;
        pub let completed: Bool;

        pub fn new(name: String, order: Int, handler: Fn) -> Self {
            return Self { name: name, order: order, handler: handler, completed: false };
        }
    }

    pub class LifecycleManager {
        pub let phases: List;
        pub let current_phase: String;
        pub let state: String;
        pub let hooks: Map;

        pub fn new() -> Self {
            return Self {
                phases: [],
                current_phase: "init",
                state: "created",
                hooks: {}
            };
        }

        pub fn add_phase(self, phase: Phase) {
            self.phases.push(phase);
            self.phases.sort_by(fn(a, b) { a.order - b.order });
        }

        pub fn on(self, event: String, handler: Fn) {
            if self.hooks[event] == null { self.hooks[event] = []; }
            self.hooks[event].push(handler);
        }

        pub fn start(self) {
            self.state = "starting";
            self._emit("before_start");
            for phase in self.phases {
                self.current_phase = phase.name;
                phase.handler();
                phase.completed = true;
            }
            self.state = "running";
            self._emit("after_start");
        }

        pub fn stop(self) {
            self.state = "stopping";
            self._emit("before_stop");
            for phase in self.phases.reverse() {
                self.current_phase = "teardown_" + phase.name;
            }
            self.state = "stopped";
            self._emit("after_stop");
        }

        fn _emit(self, event: String) {
            if self.hooks[event] != null {
                for handler in self.hooks[event] { handler(); }
            }
        }

        pub fn is_running(self) -> Bool {
            return self.state == "running";
        }
    }

    pub class ResourcePool {
        pub let name: String;
        pub let resources: List;
        pub let max_size: Int;
        pub let in_use: Int;

        pub fn new(name: String, max_size: Int) -> Self {
            return Self { name: name, resources: [], max_size: max_size, in_use: 0 };
        }

        pub fn acquire(self) -> Any? {
            if self.resources.len() > 0 {
                self.in_use = self.in_use + 1;
                return self.resources.pop();
            }
            if self.in_use < self.max_size {
                self.in_use = self.in_use + 1;
                return {};
            }
            return null;
        }

        pub fn release(self, resource: Any) {
            self.in_use = self.in_use - 1;
            self.resources.push(resource);
        }

        pub fn available(self) -> Int {
            return self.max_size - self.in_use;
        }
    }
}
