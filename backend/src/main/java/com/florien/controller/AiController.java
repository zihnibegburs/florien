package com.florien.controller;

import com.florien.dto.ai.*;
import com.florien.service.AiService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/assist")
@RequiredArgsConstructor
public class AiController {

    private final AiService aiService;

    @PostMapping("/breakdown")
    public AiBreakdownResponse breakdown(@Valid @RequestBody AiBreakdownRequest request) {
        return aiService.breakdown(request.task());
    }

    @PostMapping("/plan")
    public AiPlanResponse plan(@Valid @RequestBody AiPlanRequest request) {
        return aiService.plan(request.input(), request.date());
    }
}
