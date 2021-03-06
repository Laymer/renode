*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${CURDIR}/../../src/Renode/RobotFrameworkEngine/renode-keywords.robot

*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/hifive_unleashed.resc
${UART}                       sysbus.uart0

*** Keywords ***
Prepare Machine
    # we use special FDT that contains spi sensors
    Execute Command           \$fdt?=@http://antmicro.com/projects/renode/hifive-unleashed--devicetree-tests.dtb-s_8718-ba79c50f59ec31c6317ba31d1eeebee2b4fb3d89
    Execute Script            ${SCRIPT}

    # attach SPI sensor
    Execute Command           machine LoadPlatformDescriptionFromString "lm74_1: Sensors.TI_LM74 @ qspi1 0x0"
    Execute Command           machine LoadPlatformDescriptionFromString "lm74_2: Sensors.TI_LM74 @ qspi1 0x1"

    # attach I2C sensors
    Execute Command           machine LoadPlatformDescriptionFromString "si7021: Sensors.SI70xx @ i2c 0x40 { model: Model.SI7021 }"

*** Test Cases ***
Should Boot Linux
    [Documentation]           Boots Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  interrupts
    Prepare Machine

    Create Terminal Tester    ${UART}  prompt=\#
    Start Emulation

    Wait For Prompt On Uart   buildroot login  timeout=120
    Write Line To Uart        root
    Wait For Prompt On Uart   Password         timeout=60
    Write Line To Uart        root             waitForEcho=false
    Wait For Prompt On Uart

    Provides                  booted-linux

Should Ls
    [Documentation]           Tests shell responsiveness in Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  interrupts
    Requires                  booted-linux

    Write Line To Uart        ls --color=never /
    Wait For Line On Uart     proc

Should Read Temperature From SPI sensors
    [Documentation]           Reads temperature from SPI sensor in Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  spi  sensors
    Requires                  booted-linux

    Execute Command           qspi1.lm74_1 Temperature 36.5
    Execute Command           qspi1.lm74_2 Temperature 73

    Write Line To Uart        cd /sys/class/spi_master/spi0/spi0.0/hwmon/hwmon0
    Write Line To Uart        cat temp1_input
    Wait For Line On Uart     36500

    Write Line To Uart        cd /sys/class/spi_master/spi0/spi0.1/hwmon/hwmon1
    Write Line To Uart        cat temp1_input
    Wait For Line On Uart     73000

Should Detect I2C sensor
    [Documentation]           Tests I2C controller in Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  i2c
    Requires                  booted-linux

    Write Line To Uart        i2cdetect 0
    Wait For Prompt On Uart   Continue? [y/N]
    Write Line To Uart        y

    Wait For Line On Uart     40: 40 --

Should Read Temperature From I2C sensor
    [Documentation]           Reads temperature from I2C sensor in Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  i2c  sensors
    Requires                  booted-linux

    Execute Command           i2c.si7021 Temperature 36.6

    Write Line To Uart        echo "si7020 0x40" > /sys/class/i2c-dev/i2c-0/device/new_device
    Wait For Line On Uart     Instantiated device si7020 at 0x40

    Write Line To Uart        cd /sys/class/i2c-dev/i2c-0/device/0-0040/iio:device0
    # here we read a RAW value from the device
    # warning: the driver uses different equation to calculate the actual value than the documentation says, so it will differ from what we set in the peripheral
    Write Line To Uart        cat in_temp_raw
    Wait For Line On Uart     7780
