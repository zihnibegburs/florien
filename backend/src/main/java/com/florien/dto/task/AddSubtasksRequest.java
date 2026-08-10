package com.florien.dto.task;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record AddSubtasksRequest(
        @NotEmpty @Valid List<SubtaskRequest> subtasks
) {}
