package TNB.Zero_to_Deploy;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("prod")
class ZeroToDeployApplicationProfileTest {

    @Value("${app.environment}")
    private String environment;

    @Test
    void appEnvironment_shouldResolveToProd_whenProdProfileIsActive() {
        assertThat(environment).isEqualTo("PROD");
    }
}