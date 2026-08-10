package com.florien.dto.task;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record SubtaskRequest(
        @NotBlank @Size(max = 255) String title,
        @Positive Integer durationMinutes,
        String color
) {}
