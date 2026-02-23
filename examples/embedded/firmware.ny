# ╔══════════════════════════════════════════════════════════════════╗
# ║              NYX EMBEDDED FIRMWARE EXAMPLE (ARM CORTEX-M)        ║
# ║                Bare-Metal Firmware for Microcontroller           ║
# ╚══════════════════════════════════════════════════════════════════╝

# TARGET: ARM Cortex-M4F (STM32F4, Nordic nRF52, etc.)
# COMPILATION: nyx build firmware.ny --target thumbv7em-none-eabi --no-std -o firmware.bin

#[no_std]
#[memory_model = "manual"]
#[target = "thumbv7em-none-eabi"]

# ═══════════════════════════════════════════════════════════════════
# SECTION 1: VECTOR TABLE (ARM Cortex-M)
# ═══════════════════════════════════════════════════════════════════

#[link_section = ".vector_table"]
#[no_mangle]
pub static VECTOR_TABLE: [u32; 48] = [
    0x20010000,              # Initial stack pointer (64KB RAM)
    reset_handler as u32,    # Reset vector
    nmi_handler as u32,      # NMI
    hardfault_handler as u32,# Hard fault
    0, 0, 0, 0, 0, 0, 0,    # Reserved
    svcall_handler as u32,   # SVCall
    0, 0,                    # Reserved
    pendsv_handler as u32,   # PendSV
    systick_handler as u32,  # SysTick
    # External interrupts (32 IRQs)
    irq0_handler as u32, irq1_handler as u32, irq2_handler as u32,
    # ... (truncated for brevity, add all 32 IRQ handlers)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
]

# ═══════════════════════════════════════════════════════════════════
# SECTION 2: RESET HANDLER (Entry Point)
# ═══════════════════════════════════════════════════════════════════

#[no_mangle]
pub extern "C" fn reset_handler() -> ! {
    unsafe {
        # Initialize .data section (copy from flash to RAM)
        init_data()
        
        # Zero .bss section
        init_bss()
        
        # Enable FPU (Cortex-M4F has hardware FPU)
        enable_fpu()
        
        # Initialize system
        init_system()
        
        # Jump to main
        main()
    }
}

fn init_data() {
    extern "C" {
        static mut __data_start: u32
        static mut __data_end: u32
        static __data_load: u32
    }
    
    unsafe {
        let mut src = &__data_load as *const u32
        let mut dst = &mut __data_start as *mut u32
        let end = &__data_end as *const u32
        
        while dst < end {
            *dst = *src
            src = src.offset(1)
            dst = dst.offset(1)
        }
    }
}

fn init_bss() {
    extern "C" {
        static mut __bss_start: u32
        static mut __bss_end: u32
    }
    
    unsafe {
        let mut dst = &mut __bss_start as *mut u32
        let end = &__bss_end as *const u32
        
        while dst < end {
            *dst = 0
            dst = dst.offset(1)
        }
    }
}

fn enable_fpu() {
    unsafe {
        # Enable CP10 and CP11 coprocessors (FPU)
        const CPACR: *mut u32 = 0xE000ED88 as *mut u32
        *CPACR |= (0xF << 20)  # Full access to CP10 and CP11
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 3: EXCEPTION HANDLERS
# ═══════════════════════════════════════════════════════════════════

#[no_mangle]
extern "C" fn nmi_handler() {
    loop {}
}

#[no_mangle]
extern "C" fn hardfault_handler() {
    # Hard fault - blink LED rapidly
    unsafe {
        loop {
            gpio_set_pin(LED_PIN, true)
            delay_ms(100)
            gpio_set_pin(LED_PIN, false)
            delay_ms(100)
        }
    }
}

#[no_mangle]
extern "C" fn svcall_handler() {}

#[no_mangle]
extern "C" fn pendsv_handler() {}

static mut SYSTICK_COUNTER: u32 = 0

#[no_mangle]
extern "C" fn systick_handler() {
    unsafe {
        SYSTICK_COUNTER += 1
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 4: HARDWARE REGISTERS (Memory-Mapped I/O)
# ═══════════════════════════════════════════════════════════════════

# Example: STM32F4xx register map
const RCC_BASE: u32 = 0x40023800
const GPIOA_BASE: u32 = 0x40020000
const USART1_BASE: u32 = 0x40011000
const TIM2_BASE: u32 = 0x40000000
const ADC1_BASE: u32 = 0x40012000

# RCC (Reset and Clock Control)
const RCC_AHB1ENR: *mut u32 = (RCC_BASE + 0x30) as *mut u32
const RCC_APB1ENR: *mut u32 = (RCC_BASE + 0x40) as *mut u32
const RCC_APB2ENR: *mut u32 = (RCC_BASE + 0x44) as *mut u32

# GPIO registers
struct GPIO {
    MODER: u32,    # Mode register
    OTYPER: u32,   # Output type register
    OSPEEDR: u32,  # Output speed register
    PUPDR: u32,    # Pull-up/pull-down register
    IDR: u32,      # Input data register
    ODR: u32,      # Output data register
    BSRR: u32,     # Bit set/reset register
    LCKR: u32,     # Lock register
    AFR: [u32; 2]  # Alternate function registers
}

# USART registers
struct USART {
    SR: u32,       # Status register
    DR: u32,       # Data register
    BRR: u32,      # Baud rate register
    CR1: u32,      # Control register 1
    CR2: u32,      # Control register 2
    CR3: u32       # Control register 3
}

# Timer registers
struct Timer {
    CR1: u32,      # Control register 1
    CR2: u32,      # Control register 2
    SMCR: u32,     # Slave mode control register
    DIER: u32,     # DMA/Interrupt enable register
    SR: u32,       # Status register
    EGR: u32,      # Event generation register
    CCMR1: u32,    # Capture/compare mode register 1
    CCMR2: u32,    # Capture/compare mode register 2
    CCER: u32,     # Capture/compare enable register
    CNT: u32,      # Counter
    PSC: u32,      # Prescaler
    ARR: u32,      # Auto-reload register
    CCR1: u32,     # Capture/compare register 1
    CCR2: u32,     # Capture/compare register 2
    CCR3: u32,     # Capture/compare register 3
    CCR4: u32      # Capture/compare register 4
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 5: SYSTEM INITIALIZATION
# ═══════════════════════════════════════════════════════════════════

const CPU_FREQ_HZ: u32 = 168_000_000  # 168 MHz (STM32F4)

fn init_system() {
    # Configure system clock to 168 MHz (using PLL)
    init_clock()
    
    # Initialize SysTick timer (1ms tick)
    init_systick()
    
    # Enable GPIO clocks
    unsafe {
        *RCC_AHB1ENR |= 0x1  # Enable GPIOA
    }
}

fn init_clock() {
    # For simplicity, assume bootloader already configured PLL
    # In real firmware, you would:
    # 1. Configure HSE (external oscillator)
    # 2. Set up PLL (multiply/divide factors)
    # 3. Switch system clock to PLL
    # 4. Configure flash latency
}

fn init_systick() {
    const SYSTICK_BASE: u32 = 0xE000E010
    const SYST_CSR: *mut u32 = (SYSTICK_BASE + 0x00) as *mut u32
    const SYST_RVR: *mut u32 = (SYSTICK_BASE + 0x04) as *mut u32
    
    unsafe {
        # Reload value for 1ms tick
        *SYST_RVR = CPU_FREQ_HZ / 1000 - 1
        
        # Enable SysTick with interrupt
        *SYST_CSR = 0x7  # Enable | TickInt | ClkSource
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 6: GPIO DRIVER
# ═══════════════════════════════════════════════════════════════════

const LED_PIN: u8 = 5  # PA5 (on-board LED for many boards)

fn gpio_init_pin(pin: u8, mode: u8) {
    let gpio = GPIOA_BASE as *mut GPIO
    
    unsafe {
        # Set pin mode (00=input, 01=output, 10=alternate, 11=analog)
        let shift = pin * 2
        (*gpio).MODER &= !(0x3 << shift)
        (*gpio).MODER |= (mode as u32) << shift
        
        # Set output type (0=push-pull, 1=open-drain)
        (*gpio).OTYPER &= !(1 << pin)
        
        # Set speed (11=very high speed)
        (*gpio).OSPEEDR |= 0x3 << shift
        
        # No pull-up/pull-down
        (*gpio).PUPDR &= !(0x3 << shift)
    }
}

fn gpio_set_pin(pin: u8, state: bool) {
    let gpio = GPIOA_BASE as *mut GPIO
    
    unsafe {
        if state {
            # Set bit (high)
            (*gpio).BSRR = 1 << pin
        } else {
            # Reset bit (low)
            (*gpio).BSRR = 1 << (pin + 16)
        }
    }
}

fn gpio_read_pin(pin: u8) -> bool {
    let gpio = GPIOA_BASE as *mut GPIO
    
    unsafe {
        return ((*gpio).IDR & (1 << pin)) != 0
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 7: UART DRIVER (Serial Communication)
# ═══════════════════════════════════════════════════════════════════

fn uart_init(baud_rate: u32) {
    unsafe {
        # Enable USART1 clock
        *RCC_APB2ENR |= (1 << 4)
        
        let uart = USART1_BASE as *mut USART
        
        # Disable USART
        (*uart).CR1 &= !(1 << 13)
        
        # Configure baud rate (assuming 84 MHz APB2 clock)
        let brr = (84_000_000 + baud_rate / 2) / baud_rate
        (*uart).BRR = brr
        
        # 8 data bits, 1 stop bit, no parity
        (*uart).CR1 = 0
        (*uart).CR2 = 0
        
        # Enable TX and RX
        (*uart).CR1 |= (1 << 3) | (1 << 2)  # TE | RE
        
        # Enable USART
        (*uart).CR1 |= (1 << 13)  # UE
    }
}

fn uart_send_byte(byte: u8) {
    let uart = USART1_BASE as *mut USART
    
    unsafe {
        # Wait until TX buffer empty
        while ((*uart).SR & (1 << 7)) == 0 {}
        
        # Write data
        (*uart).DR = byte as u32
    }
}

fn uart_send_string(s: &str) {
    for byte in s.bytes() {
        uart_send_byte(byte)
    }
}

fn uart_receive_byte() -> u8 {
    let uart = USART1_BASE as *mut USART
    
    unsafe {
        # Wait until data available
        while ((*uart).SR & (1 << 5)) == 0 {}
        
        return (*uart).DR as u8
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 8: TIMER/PWM DRIVER
# ═══════════════════════════════════════════════════════════════════

fn timer_init_pwm(pin: u8) {
    unsafe {
        # Enable TIM2 clock
        *RCC_APB1ENR |= (1 << 0)
        
        let timer = TIM2_BASE as *mut Timer
        
        # Set prescaler (84 MHz / 84 = 1 MHz)
        (*timer).PSC = 84 - 1
        
        # Set auto-reload (1 MHz / 1000 = 1 kHz PWM)
        (*timer).ARR = 1000 - 1
        
        # PWM mode 1 on channel 1
        (*timer).CCMR1 = (0x6 << 4) | (1 << 3)  # OC1M = PWM1, OC1PE = preload
        
        # Enable capture/compare output
        (*timer).CCER = (1 << 0)  # CC1E
        
        # Start timer
        (*timer).CR1 = (1 << 0)  # CEN
    }
}

fn timer_set_pwm_duty(duty_percent: u8) {
    let timer = TIM2_BASE as *mut Timer
    
    unsafe {
        # Set compare value (0-100%)
        let duty = (1000 * duty_percent as u32) / 100
        (*timer).CCR1 = duty
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 9: ADC DRIVER (Analog Input)
# ═══════════════════════════════════════════════════════════════════

fn adc_init() {
    unsafe {
        # Enable ADC1 clock
        *RCC_APB2ENR |= (1 << 8)
        
        # ADC configuration would go here
        # (simplified for brevity)
    }
}

fn adc_read_channel(channel: u8) -> u16 {
    # Read 12-bit ADC value
    # (simplified implementation)
    return 2048  # Dummy value
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 10: DELAY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════

fn delay_ms(ms: u32) {
    unsafe {
        let start = SYSTICK_COUNTER
        while (SYSTICK_COUNTER - start) < ms {}
    }
}

fn delay_us(us: u32) {
    # Busy-wait (not accurate, use timer for precision)
    let cycles = (CPU_FREQ_HZ / 1_000_000) * us / 4
    for _ in 0..cycles {
        unsafe {
            asm!("nop")
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 11: MAIN APPLICATION
# ═══════════════════════════════════════════════════════════════════

fn main() -> ! {
    # Initialize LED pin
    gpio_init_pin(LED_PIN, 0x01)  # Output mode
    
    # Initialize UART for debugging
    uart_init(115200)
    uart_send_string("Nyx Firmware Booted!\r\n")
    uart_send_string("Running on ARM Cortex-M4\r\n\r\n")
    
    # Variables
    let mut led_state = false
    let mut counter: u32 = 0
    
    # Main loop
    loop {
        # Toggle LED
        led_state = !led_state
        gpio_set_pin(LED_PIN, led_state)
        
        # Send message over UART
        uart_send_string("Counter: ")
        uart_send_u32(counter)
        uart_send_string("\r\n")
        
        counter += 1
        
        # Delay 500ms
        delay_ms(500)
    }
}

fn uart_send_u32(value: u32) {
    if value == 0 {
        uart_send_byte('0' as u8)
        return
    }
    
    let mut num = value
    let mut buffer: [u8; 10] = [0; 10]
    let mut i = 0
    
    while num > 0 {
        buffer[i] = ((num % 10) as u8) + ('0' as u8)
        num /= 10
        i += 1
    }
    
    # Send in reverse
    for j in (0..i).rev() {
        uart_send_byte(buffer[j])
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 12: EXTERNAL IRQ HANDLERS (Stubs)
# ═══════════════════════════════════════════════════════════════════

#[no_mangle]
extern "C" fn irq0_handler() {}

#[no_mangle]
extern "C" fn irq1_handler() {}

#[no_mangle]
extern "C" fn irq2_handler() {}

# ═══════════════════════════════════════════════════════════════════
# END OF FIRMWARE
# ═══════════════════════════════════════════════════════════════════

# FEATURES DEMONSTRATED:
# ✅ Bare-metal ARM Cortex-M programming
# ✅ Vector table with exception handlers
# ✅ Memory-mapped I/O (GPIO, UART, Timer)
# ✅ Hardware initialization (clocks, peripherals)
# ✅ Interrupt handling (SysTick, external IRQs)
# ✅ GPIO control (digital I/O)
# ✅ UART communication (serial debugging)
# ✅ PWM generation (motor control, LED dimming)
# ✅ ADC reading (analog sensors)
# ✅ Timing functions (delay_ms, delay_us)
