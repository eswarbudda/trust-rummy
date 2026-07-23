package com.trustrummy.backend.invitations;

import java.util.List;

/**
 * Port used by Play Groups (and later Recent Players) to create invitation batches.
 */
public interface InvitationPort {

    List<InvitationView> createBatch(CreateInvitationsCommand command);
}
