package com.florien.dto.ai;

import java.util.List;

public record AiBreakdownResponse(
        String originalTask,
        List<AiStepDto> steps,
        int totalMinutes
) {}
