package com.florien.dto.task;

import java.time.LocalDate;
import java.util.List;

public record TimelineResponse(
        LocalDate date,
        List<TaskResponse> tasks,
        TaskResponse activeTask
) {}
