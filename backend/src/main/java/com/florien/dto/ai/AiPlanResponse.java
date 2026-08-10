package com.florien.dto.ai;

import java.time.LocalDate;
import java.util.List;

public record AiPlanResponse(
        LocalDate date,
        String summary,
        List<AiPlannedTaskDto> tasks,
        int totalMinutes
) {}
