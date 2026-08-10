package com.florien.dto.ai;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AiBreakdownRequest(
        @NotBlank @Size(max = 500) String task
) {}
