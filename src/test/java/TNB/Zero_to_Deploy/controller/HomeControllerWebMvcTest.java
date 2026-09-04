package TNB.Zero_to_Deploy.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(HomeController.class)
@TestPropertySource(properties = "app.environment=PREPROD")
class HomeControllerWebMvcTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void getRoot_shouldRenderHelloViewWithPreprodEnvironment() throws Exception {
        mockMvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(view().name("hello"))
                .andExpect(model().attribute("environment", "PREPROD"))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("PREPROD")));
    }
}