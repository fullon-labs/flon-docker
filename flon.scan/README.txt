# 1. Safely modify the flon.env file using nano (or your preferred editor)
nano ~/flon.env || { echo "Error editing flon.env"; exit 1; }

# 2. Change to the .docker-build directory with error checking
cd ~/.docker-build || { echo "Error: .docker-build directory not found"; exit 1; }

# 3. Execute build.sh with proper permissions and error handling
 ./build.sh
