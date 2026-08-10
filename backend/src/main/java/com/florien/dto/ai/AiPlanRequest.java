package com.florien.dto.ai;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record AiPlanRequest(
        @NotBlank @Size(max = 2000) String input,
        LocalDate date
) {}
