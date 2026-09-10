package health.balsm.app;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import pl.leancode.patrol.PatrolJUnitRunner;

/**
 * Bridges Patrol's Dart tests into Android instrumentation. Each Dart test in
 * integration_test/patrol/ is enumerated here and run as its own JUnit case.
 *
 * <p>The package is the gradle {@code namespace} (health.balsm.app), which is
 * where MainActivity lives — deliberately NOT the applicationId
 * (app.balsm.health) the app installs under.
 */
@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameterized.Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
            (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    private final String dartTestName;

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
            (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
