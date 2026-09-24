using UnityEngine;

namespace Solena.Driving
{
    public class VehicleController : MonoBehaviour
    {
        [Header("Movement")]
        [SerializeField] private float maxSpeed = 30f;
        [SerializeField] private float acceleration = 18f;
        [SerializeField] private float reverseAcceleration = 12f;
        [SerializeField] private float steeringSpeed = 1.4f;
        [SerializeField] private float brakeForce = 20f;

        [Header("Physics")]
        [SerializeField] private new Rigidbody rigidbody;

        private float throttleInput;
        private float steeringInput;

        private void Reset()
        {
            rigidbody = GetComponent<Rigidbody>();
        }

        private void Awake()
        {
            if (rigidbody == null)
            {
                rigidbody = GetComponent<Rigidbody>();
            }

            if (rigidbody == null)
            {
                rigidbody = gameObject.AddComponent<Rigidbody>();
            }

            rigidbody.drag = 0.2f;
            rigidbody.angularDrag = 0.4f;
        }

        private void Update()
        {
            throttleInput = Input.GetAxis("Vertical");
            steeringInput = Input.GetAxis("Horizontal");
        }

        private void FixedUpdate()
        {
            if (rigidbody == null)
            {
                return;
            }

            float currentSpeed = Vector3.Dot(rigidbody.velocity, transform.forward);
            float desiredAcceleration = throttleInput > 0f ? acceleration : reverseAcceleration;

            if (throttleInput != 0f)
            {
                float allowedAcceleration = Mathf.Clamp((maxSpeed - Mathf.Abs(currentSpeed)) / maxSpeed, 0f, 1f);
                Vector3 force = transform.forward * throttleInput * desiredAcceleration * allowedAcceleration;
                rigidbody.AddForce(force, ForceMode.Acceleration);
            }
            else if (Mathf.Abs(currentSpeed) > 0.05f)
            {
                rigidbody.AddForce(-transform.forward * Mathf.Sign(currentSpeed) * brakeForce, ForceMode.Acceleration);
            }

            float steerStrength = Mathf.Clamp01(Mathf.Abs(currentSpeed) / maxSpeed);
            Quaternion yawRotation = Quaternion.Euler(0f, steeringInput * steeringSpeed * steerStrength * 35f, 0f);
            rigidbody.MoveRotation(rigidbody.rotation * yawRotation);

            rigidbody.velocity = Vector3.ClampMagnitude(rigidbody.velocity, maxSpeed);
        }
    }
}
