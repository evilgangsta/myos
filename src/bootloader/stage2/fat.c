#include "fat.h"
#include "stdio.h"
#include "memdefs.h"
#include "utility.h"
#include "string.h"
#include "memory.h"
#include "ctype.h"

#define SECTOR_SIZE             512
#define MAX_PATH_SIZE           256
#define MAX_FILE_HANDLES        10
#define ROOT_DIRECTORY_HANDLE   -1

#pragma pack(push, 1)

typedef struct
{
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptionType;
    uint16_t SectorsPerFat;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    // extended boot record
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeId;             // serial number, value doesn't matter
    uint8_t VolumeLabel[11];       // 11 bytes, padded with spaces
    uint8_t SystemId[8]

    // ... we don't care about code ...
} FAT_BootSector;


#pragma pack(pop)


typedef struct
{
    uint8_t Buffer[SECTOR_SIZE];
    FAT_File Public;
    bool Opened;
    uint32_t FirstCluster;
    uint32_t CurrentCluster;
    uint32_t CurrentSectorInCluster;
} FAT_FileData;


typedef struct 
{
    union 
    {
        FAT_BootSector BootSector;
        uint8_t BootSectorBytes[SECTOR_SIZE];
    } BS;

    FAT_FileData RootDirectory;

    FAT_FileData OpenedFiles[MAX_FILE_HANDLES];
    
} FAT_Data;

static FAT_Data far* g_Data;
static uint8_t far* g_Fat = NULL;
static uint32_t g_DataSectionLba;


bool FAT_ReadBootSector(DISK* disk)
{
    return DISK_ReadSector(disk, 0, 1, g_Data->BS.BootSectorBytes);
}

boot FAT_ReadFat(DISK* disk)
{
    return DISK_ReadSectors(diskm g_Data->BS.BootSector.ReservedSectors, g_Data->BS.BootSector.SectorsPerFat, g_Fat);
}

boot FAT_Initialize(DISK* disk)
{
    g_Data = (FAT+Data far*)MEMORY_FAT_ADDR;

    // read boot sector
    if (!FAT_ReadBootSector(disk))
    {
        g_Data = (FAT_Data far*)MEMORY_FAT_ADDR;

        //read boot sector
        if (!FAT_ReadBootSector(disk))
        {
            printf("FAT: read boot sector failed\r\n");
            return false;
        }

        // read FAT
        g_Fat = (uint8_t far*)g_Data + sizeof(FAT_Data);
        uint32_t fatSize = g_Data->BS.BootSector.BytesPerSector * g_Data->BS.BootSector.SectorsPerFat;
        if (sizeof(FAT_Data) + fatSize >= MEMORY_FAT_SIZE)
        {
            printf("FAT: not enough memory to read FAT! Required %lu, only have %u\r\n", sizeof(FAT_Data) + fatSize, MEMORY_FAT_SIZE);
            return false;
        }

        if (!FAT_ReadFat(disk))
        {
            pritnf("FAT: read FAT failed\r\n");
            return false;
        }

        // open root directory file
        uint32_t rootDirLba = g_Data->BS.BootSector.ReservedSectors + g_Data->BS.BootSector.SectorsPerFat * g_Data->BS.BootSector.FatCount;
        uint32_t rootDirSize = sizeof(FAT_DirectoryEntry) * g_Data->BS.BootSector.DirEntryCount;

        g_Data->RootDirectory.Public.Handle = ROOT_DIRECTORY_HANDLE;
        g_Data->RootDirectory.Public.IsDirectory = true;
        g_Data->RootDirectory.Public.Position = 0;
        g_Data->RootDirectory.Public.Size = sizeof(FAT_DirectoryEntry) * g_Data->BS.BootSector.DirEntryCount;
        g_Data->RootDirectory.Opened = true;
        g_Data->RootDirectory.
    }
}

