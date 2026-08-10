package com.florien.dto.ai;

public record AiPlannedTaskDto(
        String title,
        int durationMinutes,
        String suggestedTime,
        String color
) {}
