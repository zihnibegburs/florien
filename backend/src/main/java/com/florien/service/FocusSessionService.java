package com.florien.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.florien.domain.entity.Task;
import com.florien.domain.enums.TaskStatus;
import com.florien.dto.focus.FocusSessionResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
public class FocusSessionService {

    private static final String FOCUS_KEY_PREFIX = "florien:focus:";
    private static final ObjectMapper REDIS_MAPPER = new ObjectMapper();

    private final StringRedisTemplate redisTemplate;
    private final ConcurrentHashMap<UUID, String> memorySessions = new ConcurrentHashMap<>();

    public FocusSessionService(@Autowired(required = false) StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
        if (redisTemplate == null) {
            log.warn("REDIS_URL not set — focus sessions use in-memory storage (single instance only).");
        }
    }

    public void startSession(Task task) {
        FocusSessionData data = new FocusSessionData(
                task.getId().toString(),
                task.getStartedAt() != null ? task.getStartedAt().toEpochMilli() : Instant.now().toEpochMilli(),
                0L,
                null
        );
        saveSession(task.getUser().getId(), data);
    }

    public void resumeSession(Task task) {
        getSessionData(task.getUser().getId()).ifPresentOrElse(data -> {
            if (data.pausedAtMs != null) {
                data.accumulatedPauseMs += Instant.now().toEpochMilli() - data.pausedAtMs;
                data.pausedAtMs = null;
            }
            saveSession(task.getUser().getId(), data);
        }, () -> startSession(task));
    }

    public void pauseSession(UUID userId) {
        getSessionData(userId).ifPresent(data -> {
            data.pausedAtMs = Instant.now().toEpochMilli();
            saveSession(userId, data);
        });
    }

    public void clearSession(UUID userId) {
        try {
            if (redisTemplate != null) {
                redisTemplate.delete(FOCUS_KEY_PREFIX + userId);
            } else {
                memorySessions.remove(userId);
            }
        } catch (Exception e) {
            log.warn("Failed to clear focus session for user {}: {}", userId, e.getMessage());
        }
    }

    public Optional<FocusSessionResponse> getSession(UUID userId, Task task) {
        return getSessionData(userId)
                .filter(data -> data.taskId.equals(task.getId().toString()))
                .map(data -> buildResponse(task, data));
    }

    public Optional<FocusSessionResponse> getActiveSession(UUID userId, Task task) {
        if (task.getStatus() != TaskStatus.IN_PROGRESS && task.getStatus() != TaskStatus.PAUSED) {
            return Optional.empty();
        }
        return getSession(userId, task).or(() -> {
            FocusSessionData fallback = new FocusSessionData(
                    task.getId().toString(),
                    task.getStartedAt() != null ? task.getStartedAt().toEpochMilli() : Instant.now().toEpochMilli(),
                    0L,
                    task.getStatus() == TaskStatus.PAUSED ? Instant.now().toEpochMilli() : null
            );
            return Optional.of(buildResponse(task, fallback));
        });
    }

    public long getAccumulatedPauseMs(UUID userId) {
        return getSessionData(userId).map(data -> data.accumulatedPauseMs).orElse(0L);
    }

    private FocusSessionResponse buildResponse(Task task, FocusSessionData data) {
        long totalSeconds = task.getDurationMinutes() * 60L;
        long elapsedMs = computeElapsedMs(data);
        long elapsedSeconds = Math.min(elapsedMs / 1000, totalSeconds);
        long remainingSeconds = Math.max(totalSeconds - elapsedSeconds, 0);
        double progress = totalSeconds > 0 ? (elapsedSeconds * 100.0 / totalSeconds) : 0;

        return new FocusSessionResponse(
                task.getId(),
                task.getTitle(),
                task.getColor(),
                task.getDurationMinutes(),
                task.getStatus(),
                Instant.ofEpochMilli(data.startedAtMs),
                elapsedSeconds,
                remainingSeconds,
                Math.min(progress, 100.0)
        );
    }

    private long computeElapsedMs(FocusSessionData data) {
        long endMs = data.pausedAtMs != null ? data.pausedAtMs : Instant.now().toEpochMilli();
        return Math.max(0, endMs - data.startedAtMs - data.accumulatedPauseMs);
    }

    private void saveSession(UUID userId, FocusSessionData data) {
        try {
            String json = REDIS_MAPPER.writeValueAsString(data);
            if (redisTemplate != null) {
                redisTemplate.opsForValue().set(FOCUS_KEY_PREFIX + userId, json);
            } else {
                memorySessions.put(userId, json);
            }
        } catch (Exception e) {
            log.warn("Failed to save focus session for user {}: {}", userId, e.getMessage());
        }
    }

    private Optional<FocusSessionData> getSessionData(UUID userId) {
        String json = redisTemplate != null
                ? redisTemplate.opsForValue().get(FOCUS_KEY_PREFIX + userId)
                : memorySessions.get(userId);
        if (json == null) return Optional.empty();
        try {
            return Optional.of(REDIS_MAPPER.readValue(json, FocusSessionData.class));
        } catch (JsonProcessingException e) {
            return Optional.empty();
        }
    }

    static class FocusSessionData {
        public String taskId;
        public long startedAtMs;
        public long accumulatedPauseMs;
        public Long pausedAtMs;

        FocusSessionData() {}

        FocusSessionData(String taskId, long startedAtMs, long accumulatedPauseMs, Long pausedAtMs) {
            this.taskId = taskId;
            this.startedAtMs = startedAtMs;
            this.accumulatedPauseMs = accumulatedPauseMs;
            this.pausedAtMs = pausedAtMs;
        }
    }
}
