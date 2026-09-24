using UnityEngine;

namespace Solena.Bootstrap
{
    public class GameBootstrap : MonoBehaviour
    {
        [Header("Game Settings")]
        [SerializeField] private bool enableDebugLogs = true;

        private void Awake()
        {
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            DontDestroyOnLoad(gameObject);

            if (enableDebugLogs)
            {
                Debug.Log("Solena Unity bootstrap ready.");
            }
        }

        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.Escape))
            {
                Application.Quit();
            }
        }
    }
}
