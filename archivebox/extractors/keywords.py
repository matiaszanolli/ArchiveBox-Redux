__package__ = 'archivebox.extractors'

from pathlib import Path
from typing import Optional

from keybert import KeyBERT
from sentence_transformers import SentenceTransformer

from ..index.schema import Link, ArchiveResult
from ..util import (
    enforce_types,
    is_static_file
)

from ..config import (
    TIMEOUT,
    SAVE_KEYWORDS,
)
from ..logging_util import TimedProgress

@enforce_types
def should_save_keywords(link: Link, out_dir: Optional[Path]=None, overwrite: Optional[bool]=False) -> bool:
    out_dir = out_dir or Path(link.link_dir)
    if is_static_file(link.url) or not (out_dir / 'readability').exists():
        return False
    if overwrite:
        return True
    return SAVE_KEYWORDS
    
    
@enforce_types
def save_keywords(link: Link, out_dir: Optional[Path]=None, timeout: int=TIMEOUT) -> ArchiveResult:
    from core.models import Snapshot

    timer = TimedProgress(timeout, prefix='      ')
    out_dir = out_dir or Path(link.link_dir)
    cmd = []
    canonical = link.canonical_outputs()
    abs_path = out_dir.absolute()
    source = canonical["readability_path"]
    text_content = str((abs_path / source)).replace('.html', '.txt')
    status = 'succeeded'

    try:
        with open(text_content, "r") as f:
            text = f.read()

            sent_trans = SentenceTransformer('sentence-transformers/all-mpnet-base-v2')
            kw_model = KeyBERT(model=sent_trans)
            # TODO: Detect language and set stopwords according to it
            keywords = kw_model.extract_keywords(text, keyphrase_ngram_range=(1, 1), stop_words='english', 
                                                        use_mmr=True, diversity=0.3)
            keywords_list = [kw[0].lower() for kw in keywords]
            snap = Snapshot.objects.get(url=link.url, timestamp=link.timestamp)
            snap.save_tags(keywords_list)
            snap.save()
            output = str(keywords_list)

    except Exception as err:
        status = 'failed'
        output = err
    finally:
        timer.end()
    return ArchiveResult(
        cmd=cmd,
        pwd=str(out_dir),
        cmd_version="0.6.0",
        output=output,
        status=status,
        **timer.stats,
    )
