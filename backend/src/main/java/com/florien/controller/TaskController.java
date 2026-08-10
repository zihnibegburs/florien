package com.florien.controller;

import com.florien.domain.enums.DeleteRecurrenceScope;
import com.florien.dto.task.*;
import com.florien.security.CurrentUserService;
import com.florien.service.TaskService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class TaskController {

    private final TaskService taskService;
    private final CurrentUserService currentUserService;

    @GetMapping("/timeline")
    public TimelineResponse getTimeline(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        return taskService.getTimeline(currentUserService.getCurrentUser(), date);
    }

    @GetMapping("/inbox")
    public List<TaskResponse> getInbox() {
        return taskService.getInbox(currentUserService.getCurrentUser());
    }

    @PostMapping("/tasks")
    @ResponseStatus(HttpStatus.CREATED)
    public TaskResponse createTask(@Valid @RequestBody CreateTaskRequest request) {
        return taskService.createTask(currentUserService.getCurrentUser(), request);
    }

    @PostMapping("/tasks/with-subtasks")
    @ResponseStatus(HttpStatus.CREATED)
    public TaskResponse createTaskWithSubtasks(@Valid @RequestBody CreateTaskWithSubtasksRequest request) {
        return taskService.createTaskWithSubtasks(currentUserService.getCurrentUser(), request);
    }

    @PutMapping("/tasks/{id}")
    public TaskResponse updateTask(
            @PathVariable UUID id,
            @RequestBody UpdateTaskRequest request
    ) {
        return taskService.updateTask(currentUserService.getCurrentUser(), id, request);
    }

    @PostMapping("/tasks/{id}/subtasks")
    @ResponseStatus(HttpStatus.CREATED)
    public TaskResponse addSubtasks(
            @PathVariable UUID id,
            @Valid @RequestBody AddSubtasksRequest request
    ) {
        return taskService.addSubtasksToTask(currentUserService.getCurrentUser(), id, request);
    }

    @DeleteMapping("/tasks/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteTask(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "THIS") DeleteRecurrenceScope scope
    ) {
        taskService.deleteTask(currentUserService.getCurrentUser(), id, scope);
    }

    @PostMapping("/tasks/{id}/start")
    public TaskResponse startTask(@PathVariable UUID id) {
        return taskService.startTask(currentUserService.getCurrentUser(), id);
    }

    @PostMapping("/tasks/{id}/pause")
    public TaskResponse pauseTask(@PathVariable UUID id) {
        return taskService.pauseTask(currentUserService.getCurrentUser(), id);
    }

    @PostMapping("/tasks/{id}/complete")
    public TaskResponse completeTask(@PathVariable UUID id) {
        return taskService.completeTask(currentUserService.getCurrentUser(), id);
    }

    @PostMapping("/tasks/{id}/uncomplete")
    public TaskResponse uncompleteTask(@PathVariable UUID id) {
        return taskService.uncompleteTask(currentUserService.getCurrentUser(), id);
    }

    @PostMapping("/inbox/{id}/schedule")
    public TaskResponse scheduleFromInbox(
            @PathVariable UUID id,
            @RequestParam Instant scheduledAt
    ) {
        return taskService.scheduleFromInbox(
                currentUserService.getCurrentUser(), id, scheduledAt
        );
    }
}
