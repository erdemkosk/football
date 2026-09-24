#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <algorithm>
#include <cmath>
#include <vector>

using namespace godot;

class MatchKernels : public RefCounted {
    GDCLASS(MatchKernels, RefCounted)
    // Match GDScript's float32 vector operations and float64 scalar arithmetic.
    // Do not enable fast-math or fused multiply-add: decision equality matters.
    static double arrival(Vector3 position, Vector3 motion, double movement_speed,
                          Vector3 point, double reaction) {
        Vector3 offset = (point - position - motion * real_t(reaction)) * Vector3(1, 0, 1);
        double distance = std::max(0.0, double(offset.length()) - .85);
        double closing = std::max(0.0, double(motion.dot(offset.normalized())));
        double pace = std::clamp(std::max(movement_speed, closing), 1.0, 8.8);
        double initial = std::min(closing, pace);
        double accelerating = (pace * pace - initial * initial) / 24.0;
        if (distance < accelerating)
            return reaction + (std::sqrt(initial * initial + 24.0 * distance) - initial) / 12.0;
        return reaction + (pace - initial) / 12.0 + (distance - accelerating) / pace;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("lob_velocity", "origin", "target", "flight", "drag"), &MatchKernels::lob_velocity);
        ClassDB::bind_method(D_METHOD("sample_straight_flight", "origin", "velocity", "seconds", "steps", "drag"), &MatchKernels::sample_straight_flight);
        ClassDB::bind_method(D_METHOD("interception_risk", "positions", "motions", "paces", "interceptors", "points", "times", "reaction", "delay", "receiver_position", "receiver_motion", "receiver_pace", "recipient", "risk"), &MatchKernels::interception_risk);
    }
public:
    Vector3 lob_velocity(Vector3 origin, Vector3 target, double flight, double drag) const {
        Vector3 launch = (target - origin) / real_t(flight) + Vector3(0, 1, 0) * real_t(4.905) * real_t(flight);
        double delta = flight / 48.0;
        for (int iteration = 0; iteration < 3; ++iteration) {
            Vector3 position = origin;
            Vector3 velocity = launch;
            for (int step = 0; step < 48; ++step) {
                Vector3 falling = velocity + Vector3(0, -1, 0) * real_t(9.81) * real_t(delta);
                Vector3 next = falling / real_t(1.0 + drag * double(falling.length()) * delta);
                position += (velocity + next) * real_t(.5) * real_t(delta);
                velocity = next;
            }
            launch += (target - position) / real_t(flight);
        }
        return launch;
    }
    PackedVector3Array sample_straight_flight(Vector3 origin, Vector3 velocity, double seconds, int64_t steps, double drag) const {
        ERR_FAIL_COND_V(steps < 0 || steps > 1000000, PackedVector3Array());
        PackedVector3Array points;
        points.resize(steps + 1);
        Vector3 *out = points.ptrw();
        out[0] = origin;
        double delta = seconds / double(std::max(int64_t(1), steps));
        for (int64_t step = 0; step < steps; ++step) {
            velocity += Vector3(0, -1, 0) * real_t(9.81) * real_t(delta);
            velocity /= real_t(1.0 + drag * double(velocity.length()) * delta);
            origin += velocity * real_t(delta);
            out[step + 1] = origin;
        }
        return points;
    }
    double interception_risk(const Array &positions, const Array &motions, const Array &paces,
                             const Array &interceptors, const PackedVector3Array &points,
                             const PackedFloat64Array &times, double reaction, double delay,
                             Vector3 receiver_position, Vector3 receiver_motion,
                             double receiver_pace, bool recipient, double risk) const {
        ERR_FAIL_COND_V(positions.size() != motions.size() || positions.size() != paces.size() || points.size() != times.size(), risk);
        struct Defender { Vector3 position, motion; double pace; };
        std::vector<Defender> defenders;
        defenders.reserve(interceptors.size());
        for (int i = 0; i < interceptors.size(); ++i) {
            int64_t index = interceptors[i];
            ERR_FAIL_INDEX_V(index, positions.size(), risk);
            defenders.push_back({positions[index], motions[index], paces[index]});
        }
        const Vector3 *samples = points.ptr();
        const double *sample_times = times.ptr();
        for (int step = 0; step < points.size() && risk < 1.0; ++step) {
            Vector3 point = samples[step];
            if (point.y > 1.9) continue;
            double time = sample_times[step];
            double receiver_time = recipient ? arrival(receiver_position, receiver_motion, receiver_pace, point, 0.0) : 10.0;
            for (const auto &defender : defenders) {
                double intercept_time = arrival(defender.position, defender.motion, defender.pace, point, reaction);
                if (intercept_time + .10 < time + delay && intercept_time + .12 < receiver_time) {
                    risk = std::max(risk, std::clamp(.65 + (time + delay - intercept_time) * .75, 0.0, 1.0));
                    if (risk >= 1.0) break;
                }
            }
        }
        return risk;
    }
};

void initialize_match(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) GDREGISTER_CLASS(MatchKernels);
}
void terminate_match(ModuleInitializationLevel) {}
extern "C" {
GDExtensionBool GDE_EXPORT match_library_init(GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize_match);
    init.register_terminator(terminate_match);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
