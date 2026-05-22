//! Helpers that calcutate the hash of the data written
//! and count the number of bytes written.

use tokio_util::io::InspectReader;

/// Copies all data from the passed reader to the passed writer.
/// Afterwards, it also returns the resulting [digest::Digest],
/// as well as the number of bytes copied.
/// The exact hash function used is left generic over all [digest::Digest].
pub async fn hash<D: digest::Digest + std::io::Write>(
    mut r: impl tokio::io::AsyncRead + Unpin,
    mut w: impl tokio::io::AsyncWrite + Unpin,
) -> std::io::Result<(digest::Output<D>, u64)> {
    let mut hasher = D::new();
    let bytes_copied = tokio::io::copy(
        &mut InspectReader::new(&mut r, |d| hasher.write_all(d).unwrap()),
        &mut w,
    )
    .await?;
    Ok((hasher.finalize(), bytes_copied))
}
