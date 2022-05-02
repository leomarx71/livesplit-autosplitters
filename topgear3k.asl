state("snes9x") {}
state("snes9x-x64") {}
state("bsnes") {}
state("higan") {}
state("emuhawk") {}

startup // Runs only once when the autosplitter is loaded
{
    refreshRate = 60;
}

init // Runs when the emulator process is found
{
    // For the variables to be defined later
    vars.totalTimeUpToLastTrack = new TimeSpan();
    vars.isInARace = false;

    var states = new Dictionary<int, long>
    {
        //Look for D0AF3505
        { 9646080, 0x97EE04 },      // Snes9x-rr 1.60
        { 13565952, 0x140925118 },  // Snes9x-rr 1.60 (x64)
        { 9027584, 0x94DB54 },      // Snes9x 1.60
        { 12836864, 0x1408D8BE8 },  // Snes9x 1.60 (x64)
        { 16019456, 0x94D144 },     // higan v106
        { 15360000, 0x8AB144 },     // higan v106.112
        { 10096640, 0x72BECC },     // bsnes v107
        { 10338304, 0x762F2C },     // bsnes v107.1
        { 47230976, 0x765F2C },     // bsnes v107.2/107.3
        { 131543040, 0xA9BD5C },    // bsnes v110
        { 51924992, 0xA9DD5C },     // bsnes v111
        { 52056064, 0xAAED7C },     // bsnes v112
        { 52477952, 0xB16D7C },     // bsnes v115
        { 7061504, 0x36F11500240 }, // BizHawk 2.3
        { 7249920, 0x36F11500240 }, // BizHawk 2.3.1
        { 6938624, 0x36F11500240 }, // BizHawk 2.3.2
        { 4546560, 0x36F05F94040 }, // BizHawk 2.6.1
        { 4538368, 0x36F05F94040 }, // BizHawk 2.6.2
        { 4571136, 0x36F05F94040 }, // BizHawk 2.8
    };

    print("modules.First().ModuleMemorySize=" + modules.First().ModuleMemorySize);

    long memoryOffset;
    if (states.TryGetValue(modules.First().ModuleMemorySize, out memoryOffset)) {
        if (memory.ProcessName.ToLower().Contains("snes9x")) {
            memoryOffset = memory.ReadValue<int>((IntPtr)memoryOffset);
        }
    }

    if (memoryOffset == 0) {
        throw new Exception("Memory not yet initialized. modules.First().ModuleMemorySize=" + modules.First().ModuleMemorySize);
    }

    vars.watchers = new MemoryWatcherList {
        new MemoryWatcher<ushort>((IntPtr)memoryOffset + 0x02A6) { Name = "raceStart" },
        new MemoryWatcher<ushort>((IntPtr)memoryOffset + 0x6991) { Name = "raceEnd" },
        new MemoryWatcher<uint>((IntPtr)memoryOffset + 0x005A) { Name = "timer" },
        new MemoryWatcher<ushort>((IntPtr)memoryOffset + 0x045C) { Name = "reset" },
    };

    vars.convertHexTimeToTimeSpan = (Func<uint, TimeSpan>)((time) => {
        int intTime = Convert.ToInt32(time);
        int centsInteger = intTime % 0x100;
        int cents = int.Parse(centsInteger.ToString("X"));
        int minutesAndSeconds = int.Parse((intTime - centsInteger).ToString("X")) / 100;
        int minutes = minutesAndSeconds / 100;
        int seconds = minutesAndSeconds % 100;
        return new TimeSpan(0, 0, 0, minutes * 60 + seconds, cents*10);
    });
}

update {
    vars.watchers.UpdateAll(game);

    print("raceStart=" + vars.watchers["raceStart"].Current);
    print("raceEnd=" + vars.watchers["raceEnd"].Current);
    print("reset=" + vars.watchers["reset"].Current);
    print("timer=" + vars.watchers["timer"].Current.ToString("X"));
    print("convertedTimer=" + vars.convertHexTimeToTimeSpan(vars.watchers["timer"].Current));

    if(vars.isInARace == false){
        var oldCountdownOn = vars.watchers["raceStart"].Old;
        var currentCountdownOn = vars.watchers["raceStart"].Current;
        vars.isInARace = oldCountdownOn == 0 && currentCountdownOn == 8;
        
        if(vars.isInARace){
            print("A RACE JUST STARTED");
        }
    }
} // Calls isloading, gameTime and reset

start // Runs if update did not return false AND the timer is not running nor paused
{
    vars.totalTimeUpToLastTrack = new TimeSpan();
    if(vars.isInARace){
        print("STARTING NOW");
    }
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
    TimeSpan gameTime = vars.totalTimeUpToLastTrack;
    if (vars.isInARace) {
        gameTime += vars.convertHexTimeToTimeSpan(vars.watchers["timer"].Current);
    }
    return gameTime;
}

reset {
    //print("reset being run");
    //print("vars.watchers[\"reset\"].Old=" + vars.watchers["reset"].Old);
    //print("vars.watchers[\"reset\"].Current=" + vars.watchers["reset"].Current);
    bool willItReset = vars.watchers["reset"].Old > 0 && vars.watchers["reset"].Current == 0;
    if (willItReset) {
        //print("It should reset!!!");
        vars.isInARace = false;
        return true;
    }
    else {
        //print("It should NOT reset!!!");
        return false;
    }
} // Calls split if it didn't return true

split {
    if(vars.isInARace && vars.watchers["raceEnd"].Changed){
        print("A RACE JUST FINISHED");
        vars.isInARace = false;
        TimeSpan raceTime = vars.convertHexTimeToTimeSpan(vars.watchers["timer"].Current);
        vars.totalTimeUpToLastTrack += raceTime;
        return true;
    }
    return false;
}


