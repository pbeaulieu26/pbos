#include <cstdint>
#include <iostream>
#include <fstream>
#include <iomanip>
#include <cstring>

namespace
{
  const int FAT_FILENAME_LENGTH = 11;
}

using byte = uint8_t;
using word = uint16_t;
using dword = uint32_t;

struct __attribute__((__packed__)) BootSector
{
  // Boot parameter block
  word jmp;
  byte nop = 0;

  char bdb_oem[8];
  word bdb_bytes_per_sector;
  byte bdb_sectors_per_cluster;
  word bdb_num_reserved_sectors;
  byte bdb_num_fat;
  word bdb_num_root_dir_entries;
  word bdb_total_sectors;

  byte bdb_media_desc_type;
  word bdb_sectors_per_fat;
  word bdb_sectors_per_track;
  word bdb_num_heads;
  dword bdb_hidden_sectors;
  dword bdb_large_sector_count;

  // Extended boot record
  byte ebr_drive_number;
  byte ebr_reserved;
  byte ebr_signature;
  byte ebr_serial_number[4];
  char ebr_volume_label[11];
  char ebr_system_id[8];
};

struct __attribute__((__packed__)) RootDirectoryEntry
{
  char fileName[FAT_FILENAME_LENGTH];
  byte attributes;
  byte reserved;
  byte creationTimeTensSec; // Range 0-199 inclusive
  word creationTime; // Hour 5 bits
                     // Minutes 6 bits
                     // Seconds 5 bits Multiply secs by 2
  word creationDate; // Year 7 bits
                     // Month 4 bits
                     // Day 5 bits Multiply secs by 2
  word lastAccessedDate; // Same format as creationDate
  word hightFirstClusterNumber;
  word lastModificationTime; // Same format as creationTime
  word lastModificationDate; // Same format as creationDate
  word lowFirstClusterNumber;
  dword fileSize; // Bytes
};

struct Fat12
{
  ~Fat12()
  {
    delete[] fileAllocationTable;
    delete[] rootDirEntries;
  }
  
  BootSector boot;
  byte* fileAllocationTable;
  RootDirectoryEntry* rootDirEntries;
};

void printMemory(byte* buffer, size_t count, bool asText = false)
{
  std::ios_base::fmtflags flags(std::cout.flags());

  for (size_t i = 0; i < count; i++)
  {
    int value = (int)*(buffer + i);
    if (asText && isprint(value))
    {
      std::cout << (char)value;
    }
    else
    {
      std::cout << std::setw(2) << std::hex << value << " ";
    }
  }
  std::cout << std::endl;

  std::cout.flags(flags);
}

int rootDirectoryEndSector(const Fat12& fs)
{
  int rootDirSectors = ((fs.boot.bdb_num_root_dir_entries * sizeof(RootDirectoryEntry)) + (fs.boot.bdb_bytes_per_sector - 1))
                         / fs.boot.bdb_bytes_per_sector;
  int rootDirStartSector = fs.boot.bdb_num_reserved_sectors + fs.boot.bdb_num_fat * fs.boot.bdb_sectors_per_fat;
  return rootDirSectors + rootDirStartSector;
}

bool readSectors(std::ifstream& is, Fat12& fs, dword lba, size_t sectorsToRead, byte* buffer)
{
  is.seekg(lba * fs.boot.bdb_bytes_per_sector);
  is.read((char*)buffer, sectorsToRead * fs.boot.bdb_bytes_per_sector);
  is.seekg (0, is.beg); // return to start
  return (bool)is;
}

bool readRootDirectory(std::ifstream& is, Fat12& fs, std::string& outErrorMsg)
{
  // Allocate for number of root dir entries
  fs.rootDirEntries = new RootDirectoryEntry[fs.boot.bdb_num_root_dir_entries];

  int rootDirSectors = ((fs.boot.bdb_num_root_dir_entries * sizeof(RootDirectoryEntry)) + (fs.boot.bdb_bytes_per_sector - 1))
                         / fs.boot.bdb_bytes_per_sector;
  int rootDirStartSector = fs.boot.bdb_num_reserved_sectors + fs.boot.bdb_num_fat * fs.boot.bdb_sectors_per_fat;

  if (!readSectors(is, fs, rootDirStartSector, rootDirSectors, (byte*)fs.rootDirEntries))
  {
    outErrorMsg = "Could not read Root Directory";
  }

  return true;
}

bool readFileAllocationTable(std::ifstream& is, Fat12& fs, std::string& outErrorMsg)
{
  // Allocate sectors for file allocation table
  fs.fileAllocationTable = new byte[fs.boot.bdb_sectors_per_fat * fs.boot.bdb_bytes_per_sector];

  int fatStartSector = fs.boot.bdb_num_reserved_sectors; // starts after reserved sectors (boot)
  if (!readSectors(is, fs, fatStartSector, fs.boot.bdb_sectors_per_fat, fs.fileAllocationTable))
  {
    outErrorMsg = "Could not read File Allocation Table";
  }

  return true;
}

bool readBootSector(std::ifstream& is, Fat12& fs, std::string& outErrorMsg)
{
  is.read((char*)&fs.boot, sizeof(fs.boot));

  if (!is)
  {
    outErrorMsg = "Error: File system cannot be read. Only " + std::to_string(is.gcount()) + " could be read.";
    return false;
  }

  return true;
}

bool readFileSystem(std::ifstream& is, Fat12& fs, std::string& outErrorMsg)
{
  if (!readBootSector(is, fs, outErrorMsg))
  {
    return false;
  }

  if (!readFileAllocationTable(is, fs, outErrorMsg))
  {
    return false;
  }

  if (!readRootDirectory(is, fs, outErrorMsg))
  {
    return false;
  }

  return true;
}

bool readFile(RootDirectoryEntry* fileEntry, byte* buffer, std::ifstream& is, Fat12& fs)
{
  auto dataStartSector = rootDirectoryEndSector(fs);
  word currentCluster = fileEntry->lowFirstClusterNumber;

  bool ok = true;
  int offsetByte = 0;
  do
  {
    dword lba = dataStartSector + (currentCluster - 2) * fs.boot.bdb_sectors_per_cluster;
    ok = readSectors(is, fs, lba, fs.boot.bdb_sectors_per_cluster, buffer + offsetByte);
    offsetByte += fs.boot.bdb_sectors_per_cluster * fs.boot.bdb_bytes_per_sector;

    int fatIndex = currentCluster * 3 / 2;
    int fatIndexRemainder = currentCluster * 3 % 2;
    if (fatIndexRemainder == 0)
    {
      currentCluster = *((word*)(fs.fileAllocationTable + fatIndex)) & 0x0FFF;
    }
    else
    {
      currentCluster = *((word*)(fs.fileAllocationTable + fatIndex)) >> 4;
    }
  } while(ok && currentCluster < 0xFF8); // 0xFF8 and higher values are end of file cluster values

  return ok;
}

RootDirectoryEntry* findFile(const char* fileName, Fat12& fs)
{
  for (int i = 0; i < fs.boot.bdb_num_root_dir_entries; i++)
  {
    auto& rootDirEntry = fs.rootDirEntries[i];
    if (std::memcmp(rootDirEntry.fileName, fileName, FAT_FILENAME_LENGTH) == 0)
    {
      return &rootDirEntry;
    }
  }

  return nullptr;
}

int main(int argc, char** argv)
{
  if (argc != 2)
  {
    std::cout << "Missing fileName parameter." << std::endl;;
    return -1;
  }

  std::string fileName = argv[1];
  std::ifstream is;
  is.open(fileName, std::ios::in | std::ios::binary);
  if (!is.is_open())
  {
    std::cout << "Cannot open file..." << std::endl; 
    return -1;
  }

  Fat12 fs;
  std::string errorMsg;
  if (!readFileSystem(is, fs, errorMsg))
  {
    std::cout << errorMsg << std::endl;
    is.close();
    return -1;
  }

  auto* fileEntry = findFile("TEST    TXT", fs);
  if (!fileEntry)
  {
    std::cout << "Could not find file." << std::endl;
    is.close();
    return -1;
  }

  size_t bufferSize = fileEntry->fileSize + fs.boot.bdb_bytes_per_sector;
  byte* buffer = new byte[bufferSize];
  if (!readFile(fileEntry, buffer, is, fs))
  {
    std::cout << "Could not read file." << std::endl;
    is.close();
    return -1;
  }

  printMemory(buffer, fileEntry->fileSize, true);

  delete[] buffer;
  is.close();
  return 0;
}