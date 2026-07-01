package com.example.runlog

import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ElevationGainedRecord
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.PlannedExerciseSessionRecord
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.Instant

/// health 패키지가 노출하지 않는 Health Connect 데이터(운동 세그먼트,
/// 상승고도, VO2max)를 직접 읽는 보조 채널.
class MainActivity : FlutterFragmentActivity() {
    private val extraPermissions = setOf(
        HealthPermission.getReadPermission(ElevationGainedRecord::class),
        HealthPermission.getReadPermission(Vo2MaxRecord::class),
        HealthPermission.getReadPermission(PlannedExerciseSessionRecord::class),
    )

    private var pendingPermResult: MethodChannel.Result? = null

    private val permLauncher: ActivityResultLauncher<Set<String>> =
        registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { granted ->
            pendingPermResult?.success(granted.containsAll(extraPermissions))
            pendingPermResult = null
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "runlog/hc_extra"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestExtraPermissions" -> requestExtraPermissions(result)
                "getSessionDetails" -> readSessionDetails(
                    call.argument<Long>("startMs")!!,
                    call.argument<Long>("endMs")!!,
                    result
                )
                "getRawSessions" -> readRawSessions(
                    call.argument<Long>("startMs")!!,
                    call.argument<Long>("endMs")!!,
                    result
                )
                "getPlannedSessions" -> readPlannedSessions(
                    call.argument<Long>("startMs")!!,
                    call.argument<Long>("endMs")!!,
                    result
                )
                "getElevationGained" -> readElevation(
                    call.argument<Long>("startMs")!!,
                    call.argument<Long>("endMs")!!,
                    result
                )
                "getVo2MaxSeries" -> readVo2Max(
                    call.argument<Long>("startMs")!!,
                    call.argument<Long>("endMs")!!,
                    result
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun requestExtraPermissions(result: MethodChannel.Result) {
        lifecycleScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val granted =
                    client.permissionController.getGrantedPermissions()
                if (granted.containsAll(extraPermissions)) {
                    result.success(true)
                } else {
                    pendingPermResult = result
                    permLauncher.launch(extraPermissions)
                }
            } catch (e: Exception) {
                result.error("HC_ERROR", e.message, null)
            }
        }
    }

    private fun readSessionDetails(
        startMs: Long, endMs: Long, result: MethodChannel.Result
    ) {
        lifecycleScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val resp = client.readRecords(
                    ReadRecordsRequest(
                        ExerciseSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(
                            Instant.ofEpochMilli(startMs),
                            Instant.ofEpochMilli(endMs)
                        )
                    )
                )
                val sessions = resp.records.map { rec ->
                    mapOf(
                        "uuid" to rec.metadata.id,
                        "segments" to rec.segments.map { seg ->
                            mapOf(
                                "startMs" to seg.startTime.toEpochMilli(),
                                "endMs" to seg.endTime.toEpochMilli(),
                                "type" to segmentTypeName(seg.segmentType),
                            )
                        },
                        "laps" to rec.laps.map { lap ->
                            mapOf(
                                "startMs" to lap.startTime.toEpochMilli(),
                                "endMs" to lap.endTime.toEpochMilli(),
                                "lengthM" to (lap.length?.inMeters ?: 0.0),
                            )
                        },
                    )
                }
                result.success(sessions)
            } catch (e: Exception) {
                result.error("HC_ERROR", e.message, null)
            }
        }
    }

    /// 진단용: health 패키지를 거치지 않고 Health Connect SDK로 직접 세션 목록을 읽는다.
    /// health 패키지 쪽 필터링/변환 문제인지, HC 권한/가시성 문제인지 구분하기 위함.
    private fun readRawSessions(
        startMs: Long, endMs: Long, result: MethodChannel.Result
    ) {
        lifecycleScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val resp = client.readRecords(
                    ReadRecordsRequest(
                        ExerciseSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(
                            Instant.ofEpochMilli(startMs),
                            Instant.ofEpochMilli(endMs)
                        )
                    )
                )
                val sessions = resp.records.map { rec ->
                    mapOf(
                        "uuid" to rec.metadata.id,
                        "exerciseType" to rec.exerciseType,
                        "title" to (rec.title ?: ""),
                        "startMs" to rec.startTime.toEpochMilli(),
                        "endMs" to rec.endTime.toEpochMilli(),
                        "dataOrigin" to rec.metadata.dataOrigin.packageName,
                    )
                }
                result.success(sessions)
            } catch (e: Exception) {
                result.error("HC_ERROR", e.message, null)
            }
        }
    }

    /// 진단용: Health Connect Training Plans API의 계획된 운동(PlannedExerciseSessionRecord)을
    /// 직접 읽는다. 삼성헬스 업데이트로 인터벌 프로그램이 이 타입으로 기록되기 시작했다면
    /// ExerciseSessionRecord 조회에서는 완전히 누락된다.
    private fun readPlannedSessions(
        startMs: Long, endMs: Long, result: MethodChannel.Result
    ) {
        lifecycleScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val resp = client.readRecords(
                    ReadRecordsRequest(
                        PlannedExerciseSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(
                            Instant.ofEpochMilli(startMs),
                            Instant.ofEpochMilli(endMs)
                        )
                    )
                )
                val sessions = resp.records.map { rec ->
                    mapOf(
                        "uuid" to rec.metadata.id,
                        "title" to (rec.title ?: ""),
                        "startMs" to rec.startTime.toEpochMilli(),
                        "endMs" to rec.endTime.toEpochMilli(),
                        "completionUuid" to (rec.completedExerciseSessionId ?: ""),
                        "dataOrigin" to rec.metadata.dataOrigin.packageName,
                    )
                }
                result.success(sessions)
            } catch (e: Exception) {
                result.error("HC_ERROR", e.message, null)
            }
        }
    }

    private fun readElevation(
        startMs: Long, endMs: Long, result: MethodChannel.Result
    ) {
        lifecycleScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val resp = client.readRecords(
                    ReadRecordsRequest(
                        ElevationGainedRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(
                            Instant.ofEpochMilli(startMs),
                            Instant.ofEpochMilli(endMs)
                        )
                    )
                )
                result.success(resp.records.sumOf { it.elevation.inMeters })
            } catch (e: Exception) {
                result.error("HC_ERROR", e.message, null)
            }
        }
    }

    private fun readVo2Max(
        startMs: Long, endMs: Long, result: MethodChannel.Result
    ) {
        lifecycleScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val resp = client.readRecords(
                    ReadRecordsRequest(
                        Vo2MaxRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(
                            Instant.ofEpochMilli(startMs),
                            Instant.ofEpochMilli(endMs)
                        )
                    )
                )
                result.success(resp.records.map {
                    mapOf(
                        "timeMs" to it.time.toEpochMilli(),
                        "value" to it.vo2MillilitersPerMinuteKilogram,
                    )
                })
            } catch (e: Exception) {
                result.error("HC_ERROR", e.message, null)
            }
        }
    }

    // 심볼 참조로 매핑 — 상수값 변동에 안전
    private fun segmentTypeName(type: Int): String = when (type) {
        ExerciseSegment.EXERCISE_SEGMENT_TYPE_RUNNING -> "running"
        ExerciseSegment.EXERCISE_SEGMENT_TYPE_RUNNING_TREADMILL -> "running"
        ExerciseSegment.EXERCISE_SEGMENT_TYPE_WALKING -> "walking"
        ExerciseSegment.EXERCISE_SEGMENT_TYPE_REST -> "rest"
        ExerciseSegment.EXERCISE_SEGMENT_TYPE_PAUSE -> "pause"
        ExerciseSegment.EXERCISE_SEGMENT_TYPE_STRETCHING -> "stretching"
        ExerciseSegment.EXERCISE_SEGMENT_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING -> "hiit"
        ExerciseSegment.EXERCISE_SEGMENT_TYPE_OTHER_WORKOUT -> "other"
        else -> "unknown"
    }
}
