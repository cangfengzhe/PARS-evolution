function (file = system.file("sequences/ct.fasta", package = "seqinr"), 
          seqtype = c("DNA", "AA"), as.string = FALSE, forceDNAtolower = TRUE, 
          set.attributes = TRUE, legacy.mode = TRUE, seqonly = FALSE, 
          strip.desc = FALSE, bfa = FALSE, sizeof.longlong = .Machine$sizeof.longlong, 
          endian = .Platform$endian, apply.mask = TRUE) 
  
  
{
  seqtype <- match.arg(seqtype)
  if (!bfa) {
    lines <- readLines(file)
    if (legacy.mode) {
      comments <- grep("^;", lines)
      if (length(comments) > 0) 
        lines <- lines[-comments]
    }
    ind <- which(substr(lines, 1L, 1L) == ">")
    nseq <- length(ind)
    if (nseq == 0) {
      stop("no line starting with a > character found")
    }
    start <- ind + 1
    end <- ind - 1
    end <- c(end[-1], length(lines))
    sequences <- lapply(seq_len(nseq), function(i) paste(lines[start[i]:end[i]], 
                                                         collapse = ""))
    if (seqonly) 
      return(sequences)
    nomseq <- lapply(seq_len(nseq), function(i) {
      firstword <- strsplit(lines[ind[i]], " ")[[1]][1]
      substr(firstword, 2, nchar(firstword))
    })
    if (seqtype == "DNA") {
      if (forceDNAtolower) {
        sequences <- as.list(tolower(sequences))
      }
    }
    if (as.string == FALSE) 
      sequences <- lapply(sequences, s2c)
    if (set.attributes) {
      for (i in seq_len(nseq)) {
        Annot <- lines[ind[i]]
        if (strip.desc) 
          Annot <- substr(Annot, 2L, nchar(Annot))
        attributes(sequences[[i]]) <- list(name = nomseq[[i]], 
                                           Annot = Annot, class = switch(seqtype, AA = "SeqFastaAA", 
                                                                         DNA = "SeqFastadna"))
      }
    }
    names(sequences) <- nomseq
    return(sequences)
  }
  if (bfa) {
    if (seqtype != "DNA") 
      stop("binary fasta file available for DNA sequences only")
    mycon <- file(file, open = "rb")
    r2s <- words(4)
    readOneBFARecord <- function(con, sizeof.longlong, endian, 
                                 apply.mask) {
      len <- readBin(con, n = 1, what = "int", endian = endian)
      if (length(len) == 0) 
        return(NULL)
      name <- readBin(con, n = 1, what = "character", endian = endian)
      ori_len <- readBin(con, n = 1, what = "int", endian = endian)
      len <- readBin(con, n = 1, what = "int", endian = endian)
      seq <- readBin(con, n = len * sizeof.longlong, what = "raw", 
                     size = 1, endian = endian)
      mask <- readBin(con, n = len * sizeof.longlong, what = "raw", 
                      size = 1, endian = endian)
      if (endian == "little") {
        neword <- sizeof.longlong:1 + rep(seq(0, (len - 
                                                    1) * sizeof.longlong, by = sizeof.longlong), 
                                          each = sizeof.longlong)
        seq <- seq[neword]
        mask <- mask[neword]
      }
      seq4 <- c2s(r2s[as.integer(seq) + 1])
      seq4 <- substr(seq4, 1, ori_len)
      if (apply.mask) {
        mask4 <- c2s(r2s[as.integer(mask) + 1])
        mask4 <- substr(mask4, 1, ori_len)
        npos <- gregexpr("a", mask4, fixed = TRUE)[[1]]
        for (i in npos) substr(seq4, i, i + 1) <- "n"
      }
      return(list(seq = seq4, name = name))
    }
    sequences <- vector(mode = "list")
    nomseq <- vector(mode = "list")
    i <- 1
    repeat {
      res <- readOneBFARecord(mycon, sizeof.longlong, endian, 
                              apply.mask)
      if (is.null(res)) 
        break
      sequences[[i]] <- res$seq
      nomseq[[i]] <- res$name
      i <- i + 1
    }
    close(mycon)
    nseq <- length(sequences)
    if (seqonly) 
      return(sequences)
    if (as.string == FALSE) 
      sequences <- lapply(sequences, s2c)
    if (set.attributes) {
      for (i in seq_len(nseq)) {
        if (!strip.desc) 
          Annot <- c2s(c(">", nomseq[[i]]))
        attributes(sequences[[i]]) <- list(name = nomseq[[i]], 
                                           Annot = Annot, class = "SeqFastadna")
      }
    }
    names(sequences) <- nomseq
    return(sequences)
  }
}
<environment: namespace:seqinr>