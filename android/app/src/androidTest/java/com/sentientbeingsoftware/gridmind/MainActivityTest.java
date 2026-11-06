package com.sentientbeingsoftware.gridmind;

import androidx.test.rule.ActivityTestRule;
import org.junit.Rule;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation = (PatrolJUnitRunner) androidx.test.platform.app.InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    @Rule
    public ActivityTestRule<MainActivity> rule = new ActivityTestRule<>(MainActivity.class, true, false);

    private final String dartTestName;

    @org.junit.Test
    public void runDartTest() {
        instrumentationRun();
    }

    private void instrumentationRun() {
        ((PatrolJUnitRunner) androidx.test.platform.app.InstrumentationRegistry.getInstrumentation())
            .runDartTest(dartTestName);
    }
}
