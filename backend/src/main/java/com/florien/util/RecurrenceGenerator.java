package com.florien.util;

import com.florien.domain.enums.RecurrenceType;
import com.florien.domain.enums.RecurrenceUnit;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

public final class RecurrenceGenerator {

    private RecurrenceGenerator() {}

    public static List<Instant> generateOccurrences(
            Instant start,
            RecurrenceType type,
            int interval,
            RecurrenceUnit unit
    ) {
        if (type == null || type == RecurrenceType.NONE || start == null) {
            return List.of();
        }

        int safeInterval = Math.max(1, interval);
        int maxOccurrences = maxOccurrences(type, safeInterval, unit);
        LocalDateTime cursor = LocalDateTime.ofInstant(start, ZoneOffset.UTC);
        List<Instant> occurrences = new ArrayList<>();

        for (int i = 0; i < maxOccurrences; i++) {
            cursor = next(cursor, type, safeInterval, unit);
            occurrences.add(cursor.toInstant(ZoneOffset.UTC));
        }

        return occurrences;
    }

    private static int maxOccurrences(RecurrenceType type, int interval, RecurrenceUnit unit) {
        return switch (type) {
            case DAILY -> 89;
            case WEEKLY -> 51;
            case MONTHLY -> 11;
            case YEARLY -> 4;
            case CUSTOM -> {
                if (unit == null) yield 0;
                yield switch (unit) {
                    case DAYS -> Math.max(1, 89 / interval);
                    case WEEKS -> Math.max(1, 51 / interval);
                    case MONTHS -> Math.max(1, 11 / interval);
                };
            }
            case NONE -> 0;
        };
    }

    private static LocalDateTime next(
            LocalDateTime current,
            RecurrenceType type,
            int interval,
            RecurrenceUnit unit
    ) {
        return switch (type) {
            case DAILY -> current.plusDays(interval);
            case WEEKLY -> current.plusWeeks(interval);
            case MONTHLY -> current.plusMonths(interval);
            case YEARLY -> current.plusYears(interval);
            case CUSTOM -> {
                if (unit == null) yield current;
                yield switch (unit) {
                    case DAYS -> current.plusDays(interval);
                    case WEEKS -> current.plusWeeks(interval);
                    case MONTHS -> current.plusMonths(interval);
                };
            }
            case NONE -> current;
        };
    }
}
