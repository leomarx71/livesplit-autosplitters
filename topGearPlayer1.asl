state("higan"){}
state("bsnes"){}
state("snes9x"){}
state("snes9x-x64"){}
state("emuhawk"){}
state("retroarch"){}
state("lsnes-bsnes"){}

startup // Runs only once when the autosplitter is loaded
{
    refreshRate = 60;
	Action<string> DebugOutput = (text) => {
        print("[Top Gear Autosplitter] "+text);
    };
    vars.DebugOutput = DebugOutput;
}

init
{
    // For the variables to be defined later
    vars.previousTracksCents = 0;
    vars.isInARace = false;
    IntPtr memoryOffset = IntPtr.Zero;

    if (memory.ProcessName.ToLower().Contains("snes9x")) {
        // TODO: These should probably be module-relative offsets too. Then
        // some of this codepath can be unified with the RA stuff below.
        var versions = new Dictionary<int, long>{
            { 10330112, 0x789414 },   // snes9x 1.52-rr
            { 7729152, 0x890EE4 },    // snes9x 1.54-rr
            { 5914624, 0x6EFBA4 },    // snes9x 1.53
            { 6909952, 0x140405EC8 }, // snes9x 1.53 (x64)
            { 6447104, 0x7410D4 },    // snes9x 1.54/1.54.1
            { 7946240, 0x1404DAF18 }, // snes9x 1.54/1.54.1 (x64)
            { 6602752, 0x762874 },    // snes9x 1.55
            { 8355840, 0x1405BFDB8 }, // snes9x 1.55 (x64)
            { 6856704, 0x78528C },    // snes9x 1.56/1.56.2
            { 9003008, 0x1405D8C68 }, // snes9x 1.56 (x64)
            { 6848512, 0x7811B4 },    // snes9x 1.56.1
            { 8945664, 0x1405C80A8 }, // snes9x 1.56.1 (x64)
            { 9015296, 0x1405D9298 }, // snes9x 1.56.2 (x64)
            { 6991872, 0x7A6EE4 },    // snes9x 1.57
            { 9048064, 0x1405ACC58 }, // snes9x 1.57 (x64)
            { 7000064, 0x7A7EE4 },    // snes9x 1.58
            { 9060352, 0x1405AE848 }, // snes9x 1.58 (x64)
            { 8953856, 0x975A54 },    // snes9x 1.59.2
            { 12537856, 0x1408D86F8 },// snes9x 1.59.2 (x64)
            { 9646080, 0x97EE04 },    // Snes9x-rr 1.60
            { 13565952, 0x140925118 },// Snes9x-rr 1.60 (x64)
            { 9027584, 0x94DB54 },    // snes9x 1.60
            { 12836864, 0x1408D8BE8 } // snes9x 1.60 (x64)
        };

        long pointerAddr;
        if (versions.TryGetValue(modules.First().ModuleMemorySize, out pointerAddr)) {
            memoryOffset = memory.ReadPointer((IntPtr)pointerAddr);
        }
    } else if (memory.ProcessName.ToLower().Contains("higan") || memory.ProcessName.ToLower().Contains("bsnes") || memory.ProcessName.ToLower().Contains("emuhawk") || memory.ProcessName.ToLower().Contains("lsnes-bsnes")) {
        var versions = new Dictionary<int, long>{
            { 12509184, 0x915304 },      // higan v102
            { 13062144, 0x937324 },      // higan v103
            { 15859712, 0x952144 },      // higan v104
            { 16756736, 0x94F144 },      // higan v105tr1
            { 16019456, 0x94D144 },      // higan v106
            { 15360000, 0x8AB144 },      // higan v106.112
            { 22388736, 0xB0ECC8 },      // higan v107
            { 23142400, 0xBC7CC8 },      // higan v108
            { 23166976, 0xBCECC8 },      // higan v109
            { 23224320, 0xBDBCC8 },      // higan v110
            { 23781376, 0xBB0CC8 },      // higan v110 (x64)
            { 10096640, 0x72BECC },      // bsnes v107
            { 10338304, 0x762F2C },      // bsnes v107.1
            { 47230976, 0x765F2C },      // bsnes v107.2/107.3
            { 142282752, 0xA65464 },     // bsnes v108
            { 131354624, 0xA6ED5C },     // bsnes v109
            { 131543040, 0xA9BD5C },     // bsnes v110
            { 51924992, 0xA9DD5C },      // bsnes v111
            { 52056064, 0xAAED7C },      // bsnes v112
            // Unfortunately v113/114 cannot be supported with this style
            // of check because their size matches v115, with a different offset
            //{ 52477952, 0xB15D7C },      // bsnes v113/114
            // This is the official release of v115, the Nightly releases report as v115 but won't work with this
            { 52477952, 0xB16D7C },      // bsnes v115
            { 7061504,  0x36F11500240 }, // BizHawk 2.3
            { 7249920,  0x36F11500240 }, // BizHawk 2.3.1
            { 6938624,  0x36F11500240 }, // BizHawk 2.3.2
            { 35414016, 0x023A1BF0 },    // lsnes rr2-B23
        };

        long wramAddr;
        if (versions.TryGetValue(modules.First().ModuleMemorySize, out wramAddr)) {
            memoryOffset = (IntPtr)wramAddr;
        }
    } else if (memory.ProcessName.ToLower().Contains("retroarch")) {
        // RetroArch stores a pointer to the emulated WRAM inside itself (it
        // can get this pointer via the Core API). This happily lets this work
        // on any variant of Snes9x cores, depending only on the RA version.

        var retroarchVersions = new Dictionary<int, int>{
            { 18649088, 0x608EF0 }, // Retroarch 1.7.5 (x64)
        };
        IntPtr wramPointer = IntPtr.Zero;
        int ptrOffset;
        if (retroarchVersions.TryGetValue(modules.First().ModuleMemorySize, out ptrOffset)) {
            wramPointer = memory.ReadPointer(modules.First().BaseAddress + ptrOffset);
        }

        if (wramPointer != IntPtr.Zero) {
            memoryOffset = wramPointer;
        } else {
            // Unfortunately, Higan doesn't support that API. So if the address
            // is missing, try to grab the memory from the higan core directly.

            var higanModule = modules.FirstOrDefault(m => m.ModuleName.ToLower() == "higan_sfc_libretro.dll");
            if (higanModule != null) {
                var versions = new Dictionary<int, int>{
                    { 4980736, 0x1F3AC4 }, // higan 106 (x64)
                };
                int wramOffset;
                if (versions.TryGetValue(higanModule.ModuleMemorySize, out wramOffset)) {
                    memoryOffset = higanModule.BaseAddress + wramOffset;
                }
            }
        }
    }

    if (memoryOffset == IntPtr.Zero) {
        vars.DebugOutput("Unsupported emulator version");
        var interestingModules = modules.Where(m =>
            m.ModuleName.ToLower().EndsWith(".exe") ||
            m.ModuleName.ToLower().EndsWith("_libretro.dll"));
        foreach (var module in interestingModules) {
            vars.DebugOutput("Module '" + module.ModuleName + "' sized " + module.ModuleMemorySize.ToString());
        }
        vars.watchers = new MemoryWatcherList{};
        // Throwing prevents initialization from completing. LiveSplit will
        // retry it until it eventually works. (Which lets you load a core in
        // RA for example.)
        throw new InvalidOperationException("Unsupported emulator version");
    }

    vars.DebugOutput("Found WRAM address: 0x" + memoryOffset.ToString("X8"));
    vars.watchers = new MemoryWatcherList
    {
        new MemoryWatcher<ushort>((IntPtr)memoryOffset + 0x1F26) { Name = "playerOneFinishTime" }, //0x1F26 to get the timer of the P1
        new MemoryWatcher<byte>((IntPtr)memoryOffset + 0x1E58) { Name = "countdownOn" },
        new MemoryWatcher<ushort>((IntPtr)memoryOffset + 0x1EAE) { Name = "counter" },
        new MemoryWatcher<byte>((IntPtr)memoryOffset + 0x1E76) { Name = "playerOneCurrentLap" },
    };

    Func <bool> isRaceFinished = () => {
        var currentPlayerOneFinishTime = vars.watchers["playerOneFinishTime"].Current;
        var currentPlayerOneCurrentLap = vars.watchers["playerOneCurrentLap"].Current;
        return currentPlayerOneFinishTime > 0 &&
            currentPlayerOneFinishTime < 65535 &&
            currentPlayerOneCurrentLap > 1 &&
            currentPlayerOneCurrentLap < 10;
    };
    vars.isRaceFinished = isRaceFinished;

    Func <ushort, int> counterToCents = (ushort counter) => {
        return counter * 5 / 3;
    };
    vars.counterToCents = counterToCents;
}

update {
    vars.watchers.UpdateAll(game);

    if(vars.isInARace == false){
        var oldCountdownOn = vars.watchers["countdownOn"].Old;
        var currentCountdownOn = vars.watchers["countdownOn"].Current;
        vars.isInARace = oldCountdownOn == 1 && currentCountdownOn == 0;
        // if(vars.isInARace){
        //     print("A RACE JUST STARTED");
        // }
        return vars.isInARace;
    }
} // Calls isloading, gameTime and reset

start // Runs if update did not return false AND the timer is not running nor paused
{
    vars.previousTracksCents = 0;
    // if(vars.isInARace){
    // print("STARTING NOW");
    // }
    return vars.isInARace;
}

isLoading
{
    // From the AutoSplit documentation:
    // "If you want the Game Time to not run in between the synchronization interval and only ever return
    // the actual Game Time of the game, make sure to implement isLoading with a constant
    // return value of true."
    return true;
}

gameTime
{
    var currentCents = vars.previousTracksCents;
    if(vars.isRaceFinished() && vars.isInARace){
        currentCents += vars.counterToCents(vars.watchers["playerOneFinishTime"].Current);
    }
    else if (vars.isInARace) {
        currentCents += vars.counterToCents(vars.watchers["counter"].Current);
    }

    return new TimeSpan(0,0,0,0,currentCents*10); // Constructor expects miliseconds
}

reset {
    return false; // Never resets automatically
} // Calls split if it didn't return true

split {
    if(vars.isInARace && vars.isRaceFinished()){
        // print("A RACE JUST FINISHED");
        vars.isInARace = false;
        int cents = vars.counterToCents(vars.watchers["playerOneFinishTime"].Current);
        vars.previousTracksCents += cents;
        // print("Splitting now with time: " + cents/6000 + "\'" + (cents % 6000) / 100 + "\"" + cents % 100);
        return true;
    }
    return false;
}
