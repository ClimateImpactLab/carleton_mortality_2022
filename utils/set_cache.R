if (!exists("cache_dir")) {
	cache_dir = tempdir()
	setCacheRootPath(path=cache_dir)
	memo.csv = addMemoization(data.table::fread)
	message(paste0("Setting Cache: ", cache_dir))
}