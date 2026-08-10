package com.florien.dto.task;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;

public record CreateTaskWithSubtasksRequest(
        @NotBlank @Size(max = 255) String title,
        String description,
        String color,
        String icon,
        Instant scheduledAt,
        @NotEmpty @Valid List<SubtaskRequest> subtasks
) {}
