package TNB.Zero_to_Deploy.controller;

import org.junit.jupiter.api.Test;
import org.springframework.ui.Model;
import org.springframework.ui.ExtendedModelMap;

import static org.assertj.core.api.Assertions.assertThat;

class HomeControllerTest {

    @Test
    void devrait_retourner_la_vue_hello() {
        HomeController controller = new HomeController("TEST");
        Model model = new ExtendedModelMap();

        String viewName = controller.hello(model);

        assertThat(viewName).isEqualTo("hello");
    }

    @Test
    void devrait_ajouter_environment_au_model() {
        HomeController controller = new HomeController("PROD");
        Model model = new ExtendedModelMap();

        controller.hello(model);

        assertThat(model.getAttribute("environment")).isEqualTo("PROD");
    }
}