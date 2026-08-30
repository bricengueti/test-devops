package TNB.Zero_to_Deploy.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    private final String environment;

    public HomeController(@Value("${app.environment}") String environment) {
        this.environment = environment;
    }

    @GetMapping("/")
    public String hello(Model model) {
        model.addAttribute("environment", environment);
        return "hello";
    }
}