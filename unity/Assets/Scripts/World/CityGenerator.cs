using UnityEngine;

namespace Solena.World
{
    public class CityGenerator : MonoBehaviour
    {
        [Header("Roads")]
        [SerializeField] private int cityBlocksX = 8;
        [SerializeField] private int cityBlocksZ = 8;
        [SerializeField] private float roadWidth = 8f;
        [SerializeField] private float blockSize = 28f;

        [Header("Visuals")]
        [SerializeField] private Material roadMaterial;
        [SerializeField] private Material buildingMaterial;
        [SerializeField] private GameObject buildingPrefab;

        private void Start()
        {
            BuildCity();
        }

        private void BuildCity()
        {
            for (int x = 0; x < cityBlocksX; x++)
            {
                for (int z = 0; z < cityBlocksZ; z++)
                {
                    Vector3 roadCenter = new Vector3(x * blockSize, 0f, z * blockSize);
                    CreateRoad(roadCenter);

                    if (x > 0 && z > 0)
                    {
                        CreateBlock(BuildBlockPosition(x, z), Random.Range(3, 7));
                    }
                }
            }
        }

        private void CreateRoad(Vector3 center)
        {
            GameObject road = GameObject.CreatePrimitive(PrimitiveType.Cube);
            road.name = "Road";
            road.transform.parent = transform;
            road.transform.position = center + new Vector3(0f, 0.02f, 0f);
            road.transform.localScale = new Vector3(blockSize, 0.05f, roadWidth);

            if (roadMaterial != null)
            {
                Renderer renderer = road.GetComponent<Renderer>();
                renderer.sharedMaterial = roadMaterial;
            }
        }

        private void CreateBlock(Vector3 center, int buildingCount)
        {
            for (int i = 0; i < buildingCount; i++)
            {
                Vector3 offset = new Vector3(
                    Random.Range(-blockSize * 0.2f, blockSize * 0.2f),
                    0f,
                    Random.Range(-blockSize * 0.2f, blockSize * 0.2f));

                GameObject building = buildingPrefab != null ? Instantiate(buildingPrefab, center + offset, Quaternion.identity) : GameObject.CreatePrimitive(PrimitiveType.Cube);
                building.name = "Building_" + i;
                building.transform.parent = transform;
                building.transform.position = center + offset + new Vector3(0f, 2.5f, 0f);
                building.transform.localScale = new Vector3(
                    Random.Range(3f, 8f),
                    Random.Range(5f, 18f),
                    Random.Range(3f, 8f));

                if (buildingMaterial != null)
                {
                    Renderer renderer = building.GetComponent<Renderer>();
                    if (renderer != null)
                    {
                        renderer.sharedMaterial = buildingMaterial;
                    }
                }
            }
        }

        private Vector3 BuildBlockPosition(int x, int z)
        {
            return new Vector3(x * blockSize, 0f, z * blockSize);
        }
    }
}
