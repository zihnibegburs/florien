package com.florien.domain.repository;

import com.florien.domain.entity.Task;
import com.florien.domain.entity.User;
import com.florien.domain.enums.TaskStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TaskRepository extends JpaRepository<Task, UUID> {

    @Query("""
        SELECT t FROM Task t
        WHERE t.user = :user
          AND t.isInbox = false
          AND t.scheduledAt >= :dayStart
          AND t.scheduledAt < :dayEnd
        ORDER BY t.scheduledAt ASC, t.sortOrder ASC
        """)
    List<Task> findTimelineTasks(
            @Param("user") User user,
            @Param("dayStart") Instant dayStart,
            @Param("dayEnd") Instant dayEnd
    );

    List<Task> findByUserAndIsInboxTrueOrderByCreatedAtDesc(User user);

    Optional<Task> findByIdAndUser(UUID id, User user);

    Optional<Task> findByUserAndStatus(User user, TaskStatus status);

    List<Task> findByUserAndParentTaskIdOrderBySortOrderAsc(User user, UUID parentTaskId);

    List<Task> findByUserAndParentTaskIdInOrderBySortOrderAsc(User user, List<UUID> parentTaskIds);

    List<Task> findByUserAndRecurrenceSeriesId(User user, UUID recurrenceSeriesId);

    List<Task> findByUserAndRecurrenceSeriesIdAndScheduledAtGreaterThanEqual(
            User user,
            UUID recurrenceSeriesId,
            Instant scheduledAt
    );
}
