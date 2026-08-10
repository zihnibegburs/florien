package com.florien.domain.entity;

import com.florien.domain.enums.RecurrenceType;
import com.florien.domain.enums.RecurrenceUnit;
import com.florien.domain.enums.TaskStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "tasks")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Task {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private String title;

    private String description;

    @Column(nullable = false)
    @Builder.Default
    private String color = "#6C63FF";

    @Column(nullable = false)
    @Builder.Default
    private String icon = "task";

    @Column(name = "duration_minutes", nullable = false)
    @Builder.Default
    private Integer durationMinutes = 30;

    @Column(name = "scheduled_at")
    private Instant scheduledAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private TaskStatus status = TaskStatus.PENDING;

    @Column(name = "sort_order", nullable = false)
    @Builder.Default
    private Integer sortOrder = 0;

    @Column(name = "is_inbox", nullable = false)
    @Builder.Default
    private Boolean isInbox = false;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_task_id")
    private Task parentTask;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "started_at")
    private Instant startedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "recurrence_type", nullable = false)
    @Builder.Default
    private RecurrenceType recurrenceType = RecurrenceType.NONE;

    @Column(name = "recurrence_interval", nullable = false)
    @Builder.Default
    private Integer recurrenceInterval = 1;

    @Enumerated(EnumType.STRING)
    @Column(name = "recurrence_unit")
    private RecurrenceUnit recurrenceUnit;

    @Column(name = "recurrence_series_id")
    private UUID recurrenceSeriesId;

    @Column(length = 500)
    private String reward;

    @Column(name = "energy_level", length = 10)
    private String energyLevel;

    @Column(length = 500)
    private String motivation;

    @Column(name = "transition_buffer_minutes", nullable = false)
    @Builder.Default
    private Integer transitionBufferMinutes = 0;
}
